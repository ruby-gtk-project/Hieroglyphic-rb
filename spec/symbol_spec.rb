# frozen_string_literal: true

require_relative "../lib/symbol"

# Pins the same properties as upstream's src/classify/symbol.rs inline tests
# (mod tests): a known symbol's attributes under its id, the table's total
# size, and the from_id/id round trip holding for every entry in the table.
RSpec.describe Hieroglyphic::Symbol do
  describe ".from_id" do
    it "returns the symbol for a known id" do
      symbol = described_class.from_id("bGF0ZXgyZS1PVDEtX3RleHRhc2NpaWNpcmN1bQ==")

      expect(symbol).not_to(be_nil)
      expect(symbol.command).to(eq("\\textasciicircum"))
      expect(symbol.package).to(eq("latex2e"))
      expect(symbol.font_encoding).to(eq("OT1"))
      expect(symbol.text_mode).to(be(true))
      expect(symbol.math_mode).to(be(false))
    end

    it "returns nil for an unknown id" do
      expect(described_class.from_id("not-a-real-id")).to(be_nil)
    end
  end

  describe ".count" do
    it "matches upstream's symbol table size" do
      expect(described_class.count).to(eq(1124))
    end
  end

  describe "the from_id/id round trip" do
    it "holds for every symbol in the table" do
      described_class.table.each_value do |symbol|
        expect(described_class.from_id(symbol.id)).to(eq(symbol))
      end
    end
  end
end
