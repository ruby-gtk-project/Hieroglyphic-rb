# frozen_string_literal: true

require "adwaita"
require "json"
require "net/http"
require_relative "about"
require_relative "classifier"
require_relative "contribution_dialog"
require_relative "drawing_area"
require_relative "indicator_button"
require_relative "primary_menu"
require_relative "settings"
require_relative "symbol"
require_relative "symbol_item"
require_relative "symbol_object"

module Hieroglyphic
  # Window is the main window: the drawing area on one side, the list of
  # symbols the drawing was recognised as on the other. Wide windows put the
  # list in a sidebar, narrow ones in a bottom sheet, which is the same
  # AdwMultiLayoutView split upstream uses.
  #
  # Ported from upstream's src/window.rs and data/resources/ui/window.ui. The
  # template's bindings become explicit calls here: `stack_page` drives both
  # stacks from one setter, and `show-indicator` follows the
  # `show-contribution-nudge` key through a settings handler, since the port's
  # IndicatorButton is a plain Ruby class rather than a GObject with properties.
  class Window
    DEFAULT_WIDTH = 700
    DEFAULT_HEIGHT = 400
    # Switching out all 1k symbols takes too long, so only this many are shown.
    DISPLAYED_SYMBOLS = 25
    # The symbol the bottom bar previews before anything has been drawn, as the
    # template's placeholder does.
    PLACEHOLDER_SYMBOL_ID = "bGF0ZXgyZS1PVDEtX2JpZ2N1cA=="
    NARROW_CONDITION = "max-width: 500sp"
    UPLOAD_URL = "https://hieroglyphic-server.apps.openshift.gnome.org/v1/upload"

    # The ids of the layouts and of the slots they fill.
    SIDEBAR_LAYOUT = "sidebar"
    BOTTOM_SHEET_LAYOUT = "bottom-sheet"
    HEADERBAR_SLOT = "headerbar"
    PRIMARY_SLOT = "primary"
    SECONDARY_SLOT = "secondary"

    # The two pages both stacks switch between.
    PLACEHOLDER_PAGE = "placeholder"
    SYMBOLS_PAGE = "symbols"

    # Only these symbols are displayed when `--show-only` named some, so a
    # drawing can be checked against one symbol during development.
    attr_accessor :symbol_filter

    def initialize(app, settings: Settings.new)
      @app = app
      @settings = settings
      @symbol_filter = []
      @symbol_strokes = []
    end

    def build
      window.tap do |win|
        win.content = toast_overlay
        win.add_breakpoint(narrow_breakpoint)
        win.add_action(clear_action)
        win.add_action(contribution_dialog_action)
        win.add_action(copy_symbol_action)
        win.add_action(markup_language_action)

        toast_overlay.tap { |overlay| overlay.child = layout_view }

        layout_view.tap do |view|
          view.add_layout(sidebar_layout)
          view.add_layout(bottom_sheet_layout)
          view.set_child(PRIMARY_SLOT, drawing_overlay)
          view.set_child(SECONDARY_SLOT, symbol_pane)
          view.set_child(HEADERBAR_SLOT, header_bar)
          view.layout_name = SIDEBAR_LAYOUT
        end

        build_drawing_overlay
        build_symbol_pane
        build_header_bar
        build_bottom_bar

        clear_action.signal_connect("activate") { drawing_area.clear }
        contribution_dialog_action.signal_connect("activate") { show_contribution_dialog }
        copy_symbol_action.signal_connect("activate") { |_, id| copy_symbol_by_id(string_of(id)) }
        markup_language_action.signal_connect("activate") do |_, mode|
          change_markup_language(string_of(mode))
        end

        # started here rather than on the first drawing, so the model is read
        # off the main loop while the window is still opening
        classifier_thread

        indicator_button.show_indicator = @settings.show_contribution_nudge?
        @settings.on_change("show-contribution-nudge") do
          indicator_button.show_indicator = @settings.show_contribution_nudge?
        end

        self.stack_page = PLACEHOLDER_PAGE
      end
    end

    def present = window.present

    # Displays the symbols the given ids name, likeliest first.
    def display_symbols(ids)
      self.stack_page = SYMBOLS_PAGE
      language = @settings.markup_language

      displayable(ids, language).then do |symbols|
        symbols.first.then do |symbol|
          if symbol
            # the first symbol is the one the bottom bar previews
            preview_symbol.set_symbol(symbol, language)
          end
        end

        symbol_store.remove_all
        symbols.take(DISPLAYED_SYMBOLS).each { |symbol| symbol_store.append(SymbolObject.new(symbol)) }
        # scroll to top after updating symbols, so that the likeliest symbols
        # are visible first
        symbol_scroller.vadjustment.value = 0.0
      end
    end

    # Copies the symbol's command to the clipboard and offers the drawing that
    # produced it to the dataset.
    def copy_symbol(symbol)
      symbol.command_for(@settings.markup_language).then do |command|
        window.clipboard.set(command)
        show_toast(_("Copied “%{command}”") % {command: command})
        try_upload_data(symbol.id, @symbol_strokes)
        @symbol_strokes = []
      end
    end

    # Records the strokes that have been drawn and asks the classifier thread
    # what they are. The strokes are kept so a copied symbol can label them for
    # the dataset; the copy is what makes that safe, since the drawing area
    # keeps adding to the list it handed over.
    def classify(strokes)
      strokes.dup.then do |sample|
        @symbol_strokes = sample

        unless sample.empty?
          classifier_requests.push(sample)
        end
      end
    end

    # The strokes waiting to be classified.
    def classifier_requests = @classifier_requests ||= Thread::Queue.new

    # The thread the classifications run on. Classifying a drawing is a second
    # of arithmetic, which would stall the main loop; upstream puts it on a
    # blocking task for the same reason and hands the result back to the main
    # loop, which is what the idle source does here.
    def classifier_thread
      @classifier_thread ||= Thread.new do
        Classifier.new.then do |classifier|
          loop { publish_classifications(classifier.classify(classifier_requests.pop)) }
        end
      end
    end

    # The page both stacks show: the "No Symbols" placeholder, or the symbols.
    def stack_page=(name)
      bottom_bar_stack.visible_child_name = name
      symbol_stack.visible_child_name = name
    end

    def window
      @window ||= Adwaita::ApplicationWindow.new(@app).tap do |win|
        win.title = _("Hieroglyphic")
        win.set_default_size(DEFAULT_WIDTH, DEFAULT_HEIGHT)
        win.height_request = DEFAULT_HEIGHT
      end
    end

    def toast_overlay = @toast_overlay ||= Adwaita::ToastOverlay.new
    def layout_view = @layout_view ||= Adwaita::MultiLayoutView.new

    # The wide layout: the symbol list in a sidebar on the end side, the
    # drawing area beside it.
    def sidebar_layout
      @sidebar_layout ||= Adwaita::Layout.new(split_view).tap do |layout|
        layout.name = SIDEBAR_LAYOUT
      end
    end

    def split_view
      @split_view ||= Adwaita::OverlaySplitView.new.tap do |view|
        view.sidebar_position = :end
        view.sidebar = sidebar_page
        view.content = content_page
      end
    end

    # Adwaita::NavigationPage takes its child and title positionally, so the
    # toolbar views are built before the pages that carry them.
    def sidebar_page = @sidebar_page ||= Adwaita::NavigationPage.new(sidebar_toolbar, "Symbols")
    def content_page = @content_page ||= Adwaita::NavigationPage.new(content_toolbar, "Drawing area")

    def sidebar_toolbar
      @sidebar_toolbar ||= Adwaita::ToolbarView.new.tap do |view|
        view.add_top_bar(sidebar_headerbar_slot)
        view.content = sidebar_secondary_slot
      end
    end

    def content_toolbar
      @content_toolbar ||= Adwaita::ToolbarView.new.tap do |view|
        view.content = sidebar_primary_slot
      end
    end

    # Each layout needs slots of its own: a slot is a widget, and a widget has
    # one parent.
    def sidebar_headerbar_slot = @sidebar_headerbar_slot ||= Adwaita::LayoutSlot.new(HEADERBAR_SLOT)
    def sidebar_secondary_slot = @sidebar_secondary_slot ||= Adwaita::LayoutSlot.new(SECONDARY_SLOT)
    def sidebar_primary_slot = @sidebar_primary_slot ||= Adwaita::LayoutSlot.new(PRIMARY_SLOT)

    # The narrow layout: the drawing area above a bottom bar that previews the
    # likeliest symbol and opens a sheet with the whole list.
    def bottom_sheet_layout
      @bottom_sheet_layout ||= Adwaita::Layout.new(bottom_sheet).tap do |layout|
        layout.name = BOTTOM_SHEET_LAYOUT
      end
    end

    def bottom_sheet
      @bottom_sheet ||= Adwaita::BottomSheet.new.tap do |sheet|
        sheet.content = sheet_content_toolbar
        sheet.sheet = sheet_toolbar
        sheet.bottom_bar = bottom_bar_stack
      end
    end

    def sheet_content_toolbar
      @sheet_content_toolbar ||= Adwaita::ToolbarView.new.tap do |view|
        view.add_top_bar(sheet_headerbar_slot)
        view.content = sheet_primary_slot
      end
    end

    # The drawing area sits above the bottom bar rather than behind it.
    def sheet_primary_slot = @sheet_primary_slot ||= Adwaita::LayoutSlot.new(PRIMARY_SLOT)

    def sheet_headerbar_slot = @sheet_headerbar_slot ||= Adwaita::LayoutSlot.new(HEADERBAR_SLOT)
    def sheet_secondary_slot = @sheet_secondary_slot ||= Adwaita::LayoutSlot.new(SECONDARY_SLOT)

    def sheet_toolbar
      @sheet_toolbar ||= Adwaita::ToolbarView.new.tap do |view|
        view.add_top_bar(sheet_header_bar)
        view.content = sheet_secondary_slot
      end
    end

    def sheet_header_bar = @sheet_header_bar ||= Adwaita::HeaderBar.new

    def bottom_bar_stack
      @bottom_bar_stack ||= Gtk::Stack.new.tap do |stack|
        stack.transition_type = :crossfade
      end
    end

    def bottom_bar_placeholder
      @bottom_bar_placeholder ||= Gtk::Box.new(:horizontal, 0).tap do |box|
        box.margin_top = 6
        box.margin_bottom = 6
        box.margin_start = 15
        box.margin_end = 15
      end
    end

    def placeholder_image
      @placeholder_image ||= Gtk::Image.new.tap do |image|
        image.icon_name = "edit-symbolic"
        image.icon_size = :large
      end
    end

    def placeholder_inscriptions
      @placeholder_inscriptions ||= Gtk::Box.new(:vertical, 0).tap do |box|
        box.hexpand = true
        box.valign = :center
        box.margin_start = 15
      end
    end

    def placeholder_title
      @placeholder_title ||= Gtk::Inscription.new(_("No Symbols")).tap do |inscription|
        inscription.add_css_class("title-3")
      end
    end

    def placeholder_subtitle
      @placeholder_subtitle ||= Gtk::Inscription.new(_("Start by drawing a symbol")).tap do |inscription|
        inscription.add_css_class("caption")
      end
    end

    def bottom_bar_symbols
      @bottom_bar_symbols ||= Gtk::Box.new(:horizontal, 0).tap do |box|
        box.margin_top = 6
        box.margin_bottom = 6
        box.margin_start = 15
        box.margin_end = 15
      end
    end

    def preview_symbol
      @preview_symbol ||= SymbolItem.new(
        Symbol.from_id(PLACEHOLDER_SYMBOL_ID),
        @settings.markup_language,
      )
    end

    def all_symbols_button
      @all_symbols_button ||= Gtk::ToggleButton.new.tap do |button|
        button.icon_name = "up-symbolic"
        button.tooltip_text = _("All Symbols")
        button.valign = :center
        button.add_css_class("flat")
      end
    end

    # The drawing area, with the clear button floating over it.
    def drawing_overlay = @drawing_overlay ||= Gtk::Overlay.new

    def drawing_area = @drawing_area ||= DrawingArea.new { |strokes| classify(strokes) }

    def clear_button
      @clear_button ||= Gtk::Button.new.tap do |button|
        button.halign = :start
        button.valign = :end
        button.margin_top = 12
        button.margin_start = 18
        button.margin_bottom = 18
        button.action_name = "win.clear"
        button.add_css_class("clear-button")
        button.child = clear_button_content
      end
    end

    def clear_button_content
      @clear_button_content ||= Adwaita::ButtonContent.new.tap do |content|
        content.icon_name = "eraser-symbolic"
        content.label = _("_Clear")
        content.use_underline = true
      end
    end

    # The symbol list side: a status page until something has been drawn, the
    # list of recognised symbols afterwards.
    def symbol_pane
      @symbol_pane ||= Adwaita::ToolbarView.new.tap do |view|
        view.content = symbol_stack
      end
    end

    def symbol_stack
      @symbol_stack ||= Gtk::Stack.new.tap do |stack|
        stack.transition_type = :crossfade
      end
    end

    def symbol_status_page
      @symbol_status_page ||= Adwaita::StatusPage.new.tap do |page|
        page.icon_name = "edit-symbolic"
        page.title = _("No Symbols")
        page.description = _("Start by drawing a symbol")
        page.add_css_class("compact")
      end
    end

    def symbol_scroller
      @symbol_scroller ||= Gtk::ScrolledWindow.new.tap do |scroller|
        scroller.propagate_natural_height = true
        scroller.width_request = 330
        scroller.hscrollbar_policy = :never
        scroller.min_content_height = 200
      end
    end

    def symbol_list
      @symbol_list ||= Gtk::ListBox.new.tap do |list|
        list.selection_mode = :none
        list.add_css_class("navigation-sidebar")
      end
    end

    def symbol_store = @symbol_store ||= Gio::ListStore.new(SymbolObject)

    def header_bar
      @header_bar ||= Adwaita::HeaderBar.new.tap do |bar|
        bar.decoration_layout = ":close"
        bar.title_widget = window_title
      end
    end

    def window_title = @window_title ||= Adwaita::WindowTitle.new(_("Hieroglyphic"), "")

    def indicator_button
      @indicator_button ||= IndicatorButton.new(
        action_name:  "win.show-contribution-dialog",
        icon_name:    "document-send-symbolic",
        tooltip_text: _("Improve Hieroglyphic"),
      )
    end

    def menu_button
      @menu_button ||= Gtk::MenuButton.new.tap do |button|
        button.tooltip_text = _("Main Menu")
        button.valign = :center
        button.icon_name = "open-menu-symbolic"
        button.primary = true
        button.menu_model = PrimaryMenu.new.build
      end
    end

    def narrow_breakpoint
      @narrow_breakpoint ||= Adwaita::Breakpoint.new(
        Adwaita::BreakpointCondition.parse(NARROW_CONDITION),
      ).tap do |breakpoint|
        breakpoint.add_setter(layout_view, "layout-name", BOTTOM_SHEET_LAYOUT)
        breakpoint.signal_connect("apply") { clear_button.halign = :center }
        breakpoint.signal_connect("unapply") { clear_button.halign = :start }
      end
    end

    # Built once and presented again on each activation, so the switch keeps
    # the state the settings gave it.
    def contribution_dialog = @contribution_dialog ||= ContributionDialog.new(@settings)

    def clear_action = @clear_action ||= Gio::SimpleAction.new("clear")

    def contribution_dialog_action
      @contribution_dialog_action ||= Gio::SimpleAction.new("show-contribution-dialog")
    end

    def copy_symbol_action
      @copy_symbol_action ||= Gio::SimpleAction.new("copy-symbol", GLib::VariantType.new("s"))
    end

    def markup_language_action
      @markup_language_action ||= Gio::SimpleAction.new(
        "markup-language-mode",
        GLib::VariantType.new("s"),
        GLib::Variant.new(@settings.markup_language.to_s),
      )
    end

    private

      def build_drawing_overlay
        drawing_overlay.tap do |overlay|
          overlay.child = drawing_area.build
          overlay.add_overlay(clear_button)
        end
      end

      def build_symbol_pane
        symbol_stack.tap do |stack|
          stack.add_named(symbol_status_page, PLACEHOLDER_PAGE)
          stack.add_named(symbol_scroller, SYMBOLS_PAGE)

          symbol_scroller.tap { |scroller| scroller.child = symbol_list }

          symbol_list.tap do |list|
            list.bind_model(Gtk::NoSelection.new(symbol_store)) do |object|
              SymbolItem.new(object.symbol, @settings.markup_language).build
            end
            list.signal_connect("row-activated") { |_, row| copy_symbol_at(row.index) }
          end
        end
      end

      def build_header_bar
        header_bar.tap do |bar|
          bar.pack_start(indicator_button.build)
          bar.pack_end(menu_button)
        end
      end

      def build_bottom_bar
        bottom_bar_stack.tap do |stack|
          stack.add_named(bottom_bar_placeholder, PLACEHOLDER_PAGE)
          stack.add_named(bottom_bar_symbols, SYMBOLS_PAGE)

          bottom_bar_placeholder.tap do |box|
            box.append(placeholder_image)
            box.append(placeholder_inscriptions)

            placeholder_inscriptions.tap do |column|
              column.append(placeholder_title)
              column.append(placeholder_subtitle)
            end
          end

          bottom_bar_symbols.tap do |box|
            box.append(preview_symbol.build)
            box.append(all_symbols_button)
          end

          all_symbols_button.bind_property(
            "active",
            bottom_sheet,
            "open",
            [:bidirectional, :sync_create],
          )
          # the drawing area sits above the bottom bar rather than behind it
          bottom_sheet.bind_property(
            "bottom-bar-height",
            sheet_primary_slot,
            "margin-bottom",
            :sync_create,
          )
        end
      end

      # The symbols of the given ids that the language can actually spell, in
      # the order the ids came in. `--show-only` replaces them wholesale.
      def displayable(ids, language)
        classifications(ids)
          .filter_map { |id| Symbol.from_id(id) }
          .select { |symbol| symbol.command_for(language) }
      end

      # Shows a finished classification. It arrives on the classifier thread,
      # and every widget it touches belongs to the main loop, so the display
      # itself is queued as an idle source and runs there.
      def publish_classifications(ids)
        if ids
          GLib::Idle.add do
            display_symbols(ids)
            false
          end
        end
      end

      def classifications(ids)
        if @symbol_filter.empty?
          ids
        else
          @symbol_filter
        end
      end

      # An action's string parameter reaches the handler as a Ruby String, but
      # a caller that activates the action by hand may hand over the GLib
      # variant itself.
      def string_of(parameter)
        if parameter.is_a?(GLib::Variant)
          parameter.get_string
        else
          parameter.to_s
        end
      end

      def copy_symbol_at(position)
        symbol_store.get_item(position).then do |object|
          if object
            copy_symbol(object.symbol)
          end
        end
      end

      def copy_symbol_by_id(id)
        Symbol.from_id(id).then do |symbol|
          if symbol
            copy_symbol(symbol)
          end
        end
      end

      def show_contribution_dialog
        contribution_dialog.present(window)
        # only show nudge once, i.e. hide it after clicking the button
        @settings.show_contribution_nudge = false
      end

      def change_markup_language(mode)
        markup_language_action.state = GLib::Variant.new(mode)
        @settings.markup_language = mode
        displayed_ids.then { |ids| display_symbols(ids) }
      end

      def displayed_ids
        symbol_store.n_items.times.map { |position| symbol_store.get_item(position).symbol.id }
      end

      # Shows a basic toast with the given text, replacing any toast already
      # showing so only the most recent copy is seen.
      def show_toast(text)
        Adwaita::Toast.new(text).tap do |toast|
          toast.use_markup = false
          toast_overlay.dismiss_all
          toast_overlay.add_toast(toast)
        end
      end

      # Offers the strokes to the dataset, under the label of the symbol they
      # were copied as. Metered connections and power saving are respected, and
      # nothing is sent unless the user opted in.
      def try_upload_data(label, strokes)
        if upload_allowed?(strokes)
          upload(label, strokes)
        end
      end

      def upload_allowed?(strokes)
        !strokes.empty? &&
          @settings.contribute_data? &&
          !Gio::NetworkMonitor.default.network_metered? &&
          !power_saver_enabled?
      end

      # Gio::PowerProfileMonitor is not in every build of the bindings; where it
      # is missing, the other two checks still gate the upload.
      def power_saver_enabled?
        if Gio.const_defined?(:PowerProfileMonitor)
          Gio::PowerProfileMonitor.default.power_saver_enabled?
        else
          false
        end
      end

      # Uploads on its own thread, so the UI keeps running while it happens.
      def upload(label, strokes)
        strokes.map(&:as_json).then do |payload|
          Thread.new do
            post(label, payload)
          rescue StandardError => e
            warn("Failed to upload strokes: #{e.message}")
          end
        end
      end

      def post(label, payload)
        Net::HTTP.post(
          URI("#{UPLOAD_URL}/#{label}"),
          JSON.generate(payload),
          "Content-Type" => "application/json",
          "User-Agent"   => "Hieroglyphic/#{Rb::Version::VERSION}",
        )
      end
  end
end
