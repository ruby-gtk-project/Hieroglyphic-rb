# frozen_string_literal: true

module Hieroglyphic
  # Onnx reads an ONNX model file and runs it.
  #
  # This has no upstream file of its own: it stands in for the `ort` crate,
  # which upstream's src/classify/classifier.rs uses to load data/model.onnx and
  # run a forward pass. Ruby has no binding to ONNX Runtime in this app's gem
  # closure, so the engine is here, and it covers exactly the graph the shipped
  # model is: Conv, Relu, MaxPool, Reshape and Gemm, in NCHW layout, with
  # float32 weights. An operator outside that set is refused rather than
  # guessed at — the model is checked in beside the code, so the two cannot
  # drift apart.
  #
  # The graph is eight nodes long (two 5x5 convolutions with 16 and 32 output
  # channels, each followed by a ReLU and a 2x2 max pool, then an 800x1098
  # fully connected layer): about three million multiply-accumulates, which a
  # plain Ruby forward pass runs in roughly a second. That is why the window
  # classifies on a thread of its own, as upstream does for its own reasons.
  module Onnx
    # The ONNX TensorProto data types the engine reads.
    FLOAT = 1
    INT64 = 7

    # A dense tensor: a flat array of values in row-major order, plus the shape
    # that gives it its dimensions.
    Tensor = Data.define(:shape, :data) do
      # The number of values a tensor of the given shape holds.
      def self.element_count(shape) = shape.inject(1, :*)

      # A tensor of the given shape filled with `value`.
      def self.filled(shape, value) = new(shape: shape, data: Array.new(element_count(shape), value))

      def size = data.size

      # The tensor seen as a different shape, which must hold as many values.
      def reshape(shape)
        if Tensor.element_count(shape) != data.size
          raise(ArgumentError, "cannot reshape #{self.shape.inspect} into #{shape.inspect}")
        end

        Tensor.new(shape: shape, data: data)
      end
    end

    # Protobuf is as much of the protocol buffer wire format as reading an ONNX
    # file takes: every field of a message, by field number, without a schema.
    #
    # A parsed message is a Hash of field number to the list of values that
    # field carried. A varint field yields Integers, a length-delimited field
    # yields Strings (a nested message, a string, or a packed numeric array),
    # and a fixed-width field yields its raw bytes.
    module Protobuf
      VARINT = 0
      FIXED64 = 1
      LENGTH_DELIMITED = 2
      FIXED32 = 5

      class << self
        # Every field of the message, as a Hash of field number to values.
        def parse(bytes)
          offset = 0
          fields = {}

          while offset < bytes.bytesize
            key, offset = read_varint(bytes, offset)
            value, offset = read_value(bytes, offset, key & 0x7)
            (fields[key >> 3] ||= []) << value
          end

          fields
        end

        # The values of one field, or an empty list when the field is absent.
        def field(fields, number) = fields.fetch(number, [])

        # The single value of a field, or nil when the field is absent.
        def one(fields, number) = field(fields, number).first

        # A repeated numeric field, which the writer may have packed into one
        # length-delimited value or written out one varint at a time.
        def varints(values)
          values.flat_map do |value|
            if value.is_a?(String)
              unpack_varints(value)
            else
              [value]
            end
          end
        end

        # A signed 64-bit integer as a varint encodes it: the wire format has no
        # sign bit, so a negative value arrives as its two's complement.
        def signed(value)
          if value >= (1 << 63)
            value - (1 << 64)
          else
            value
          end
        end

        private

          def read_value(bytes, offset, wire_type)
            case wire_type
            when VARINT then read_varint(bytes, offset)
            when FIXED64 then [bytes.byteslice(offset, 8), offset + 8]
            when FIXED32 then [bytes.byteslice(offset, 4), offset + 4]
            when LENGTH_DELIMITED then read_bytes(bytes, offset)
            else
              raise(ArgumentError, "unsupported protobuf wire type #{wire_type}")
            end
          end

          def read_bytes(bytes, offset)
            read_varint(bytes, offset).then do |length, start|
              [bytes.byteslice(start, length), start + length]
            end
          end

          def read_varint(bytes, offset)
            result = 0
            shift = 0

            loop do
              byte = bytes.getbyte(offset)
              offset += 1
              result |= (byte & 0x7f) << shift
              shift += 7
              if byte < 0x80
                break
              end
            end

            [result, offset]
          end

          def unpack_varints(packed)
            offset = 0
            values = []

            while offset < packed.bytesize
              value, offset = read_varint(packed, offset)
              values << value
            end

            values
          end
      end
    end

    # Attribute is one named argument of a graph node: the ints, floats and
    # single values an operator reads its padding, strides and flags from.
    #
    # AttributeProto field numbers: 1 name, 2 f, 3 i, 7 floats, 8 ints.
    class Attribute
      attr_reader :name

      def initialize(fields)
        @name = Protobuf.one(fields, 1)
        @fields = fields
      end

      # The attribute's integer value, or `default` when it carries none.
      def int(default) = Protobuf.one(@fields, 3)&.then { |value| Protobuf.signed(value) } || default

      # The attribute's float value, or `default` when it carries none.
      def float(default) = Protobuf.one(@fields, 2)&.then { |raw| raw.unpack1("e") } || default

      # The attribute's list of integers, or `default` when it carries none.
      def ints(default)
        Protobuf.varints(Protobuf.field(@fields, 8)).then do |values|
          if values.empty?
            default
          else
            values.map { |value| Protobuf.signed(value) }
          end
        end
      end
    end

    # Node is one operator of the graph: its type, the names of the tensors it
    # reads and writes, and its attributes.
    #
    # NodeProto field numbers: 1 input, 2 output, 3 name, 4 op_type,
    # 5 attribute.
    class Node
      attr_reader :op_type, :inputs, :outputs

      def initialize(fields)
        @op_type = Protobuf.one(fields, 4)
        @inputs = Protobuf.field(fields, 1)
        @outputs = Protobuf.field(fields, 2)
        @attributes = Protobuf.field(fields, 5).to_h do |raw|
          Attribute.new(Protobuf.parse(raw)).then { |attribute| [attribute.name, attribute] }
        end
      end

      # The named attribute's integer value, or `default` when the node does not
      # carry that attribute.
      def int(name, default) = attribute(name)&.int(default) || default

      # The named attribute's float value, or `default`.
      def float(name, default) = attribute(name)&.float(default) || default

      # The named attribute's list of integers, or `default`.
      def ints(name, default) = attribute(name)&.ints(default) || default

      # The named attribute's list of integers, which the operator cannot run
      # without.
      def required_ints(name)
        ints(name, nil) || raise(ArgumentError, "#{op_type} node is missing its #{name} attribute")
      end

      private

        def attribute(name) = @attributes[name]
    end

    # Model is a loaded ONNX graph: the operators in the order they run, the
    # weights they read, and the names of the graph's input and output.
    #
    # ModelProto field 7 is the graph; GraphProto field numbers: 1 node,
    # 2 name, 5 initializer, 11 input, 12 output.
    class Model
      attr_reader :input_name, :output_name

      # The model the given .onnx file holds.
      def self.load(path) = new(File.binread(path))

      def initialize(bytes)
        Protobuf.parse(Protobuf.one(Protobuf.parse(bytes), 7)).then do |graph|
          @nodes = Protobuf.field(graph, 1).map { |raw| Node.new(Protobuf.parse(raw)) }
          @initializers = Protobuf.field(graph, 5).to_h { |raw| initializer(Protobuf.parse(raw)) }
          @input_name = value_info_name(Protobuf.one(graph, 11))
          @output_name = value_info_name(Protobuf.one(graph, 12))
        end
      end

      # Runs the graph over the given input Tensor and returns the Tensor its
      # output node produced.
      def run(input)
        @nodes.inject(@initializers.merge(@input_name => input)) do |tensors, node|
          tensors.merge(node.outputs.first => apply(node, tensors))
        end.fetch(@output_name)
      end

      private

        def apply(node, tensors)
          node.inputs.map { |name| tensors[name] }.then do |operands|
            case node.op_type
            when "Conv" then Operator.conv(node, *operands)
            when "Relu" then Operator.relu(*operands)
            when "MaxPool" then Operator.max_pool(node, *operands)
            when "Reshape" then Operator.reshape(node, *operands)
            when "Gemm" then Operator.gemm(node, *operands)
            else
              raise(NotImplementedError, "this engine does not run the ONNX operator #{node.op_type}")
            end
          end
        end

        # One weight tensor, as a [name, Tensor] pair. TensorProto field
        # numbers: 1 dims, 2 data_type, 8 name, 9 raw_data.
        def initializer(fields)
          [
            Protobuf.one(fields, 8),
            Tensor.new(
              shape: Protobuf.varints(Protobuf.field(fields, 1)).map { |dim| Protobuf.signed(dim) },
              data:  values(Protobuf.one(fields, 2), Protobuf.one(fields, 9)),
            ),
          ]
        end

        def values(data_type, raw)
          case data_type
          when FLOAT then raw.unpack("e*")
          when INT64 then raw.unpack("q<*")
          else
            raise(NotImplementedError, "this engine does not read ONNX tensor data type #{data_type}")
          end
        end

        # ValueInfoProto field 1 is the name of the tensor it describes.
        def value_info_name(raw) = Protobuf.one(Protobuf.parse(raw), 1)
    end

    # Operator is the implementation of each operator the model's graph uses.
    #
    # Every operator reads and writes NCHW tensors of Floats, and the loops are
    # written for a Ruby interpreter: the output index walks forward, the
    # in-bounds span of each kernel offset is computed once outside the inner
    # loop, and the weight is hoisted out of it.
    module Operator
      class << self
        # Rectified linear unit: the input with its negative values clamped to
        # zero.
        def relu(input) = Tensor.new(shape: input.shape, data: input.data.map { |value| [value, 0.0].max })

        # A 2D convolution of `input` with `weight`, plus `bias` per output
        # channel.
        def conv(node, input, weight, bias)
          batch, in_channels, in_height, in_width = input.shape
          out_channels, group_channels, kernel_height, kernel_width = weight.shape
          groups = node.int("group", 1)
          stride_y, stride_x = node.ints("strides", [1, 1])
          dilation_y, dilation_x = node.ints("dilations", [1, 1])
          pad_top, pad_left, pad_bottom, pad_right = node.ints("pads", [0, 0, 0, 0])

          out_height = span(
            in_height,
            pad_top,
            pad_bottom,
            kernel_height,
            dilation_y,
            stride_y,
          )
          out_width = span(
            in_width,
            pad_left,
            pad_right,
            kernel_width,
            dilation_x,
            stride_x,
          )

          Tensor.filled([batch, out_channels, out_height, out_width], 0.0).then do |output|
            batch.times do |image|
              out_channels.times do |out_channel|
                convolve_channel(
                  output.data,
                  ((image * out_channels) + out_channel) * out_height * out_width,
                  input.data,
                  (image * in_channels * in_height * in_width) +
                    ((out_channel / (out_channels / groups)) * group_channels * in_height * in_width),
                  weight.data,
                  out_channel * group_channels * kernel_height * kernel_width,
                  bias.data[out_channel],
                  {
                    channels:   group_channels,
                    in_height:  in_height,
                    in_width:   in_width,
                    out_height: out_height,
                    out_width:  out_width,
                    kernel:     [kernel_height, kernel_width],
                    stride:     [stride_y, stride_x],
                    dilation:   [dilation_y, dilation_x],
                    pad:        [pad_top, pad_left],
                  },
                )
              end
            end

            output
          end
        end

        # Max pooling over each channel's spatial window.
        def max_pool(node, input)
          batch, channels, in_height, in_width = input.shape
          kernel_height, kernel_width = node.required_ints("kernel_shape")
          stride_y, stride_x = node.ints("strides", [1, 1])
          dilation_y, dilation_x = node.ints("dilations", [1, 1])
          pad_top, pad_left, pad_bottom, pad_right = node.ints("pads", [0, 0, 0, 0])

          out_height = span(
            in_height,
            pad_top,
            pad_bottom,
            kernel_height,
            dilation_y,
            stride_y,
          )
          out_width = span(
            in_width,
            pad_left,
            pad_right,
            kernel_width,
            dilation_x,
            stride_x,
          )

          Tensor.filled([batch, channels, out_height, out_width], 0.0).then do |output|
            (batch * channels).times do |plane|
              pool_plane(
                output.data,
                plane * out_height * out_width,
                input.data,
                plane * in_height * in_width,
                {
                  in_height:  in_height,
                  in_width:   in_width,
                  out_height: out_height,
                  out_width:  out_width,
                  kernel:     [kernel_height, kernel_width],
                  stride:     [stride_y, stride_x],
                  dilation:   [dilation_y, dilation_x],
                  pad:        [pad_top, pad_left],
                },
              )
            end

            output
          end
        end

        # The input seen as the shape the second operand names. A dimension of
        # -1 is inferred from the remaining ones; a dimension of 0 copies the
        # input's, unless `allowzero` says to take it literally.
        def reshape(node, input, shape)
          node.int("allowzero", 0).then do |allowzero|
            resolve_shape(shape.data.map(&:to_i), input, allowzero).then do |resolved|
              input.reshape(resolved)
            end
          end
        end

        # General matrix multiply: alpha * A * B + beta * C, with either operand
        # optionally transposed.
        def gemm(node, input, weight, bias)
          alpha = node.float("alpha", 1.0)
          beta = node.float("beta", 1.0)
          flip = node.int("transB", 0)
          left = transposed(input, node.int("transA", 0))
          rows, inner = left.shape
          columns = columns_of(weight, flip)

          if inner_of(weight, flip) != inner
            raise(ArgumentError, "cannot multiply #{left.shape.inspect} by #{weight.shape.inspect}")
          end

          Tensor.filled([rows, columns], 0.0).then do |output|
            if flip.zero?
              multiply_into(
                output.data,
                left.data,
                weight.data,
                rows,
                inner,
                columns,
                alpha,
              )
            else
              multiply_rows_into(
                output.data,
                left.data,
                weight.data,
                rows,
                inner,
                columns,
                alpha,
              )
            end

            add_bias(
              output.data,
              bias,
              rows,
              columns,
              beta,
            )
            output
          end
        end

        private

          # The extent of one output axis of a sliding window.
          def span(extent, pad_low, pad_high, kernel, dilation, stride)
            (((extent + pad_low + pad_high) - (((kernel - 1) * dilation) + 1)) / stride) + 1
          end

          # The lowest output index whose window covers an in-bounds input
          # index, for the kernel offset already folded into `shifted`.
          def first_covered(shifted, stride)
            if shifted >= 0
              0
            else
              (-shifted + stride - 1) / stride
            end
          end

          # One output channel of a convolution: the bias, plus each input
          # channel's contribution through each kernel offset.
          def convolve_channel(out, out_base, input, in_base, weight, weight_base, bias, geometry)
            kernel_height, kernel_width = geometry[:kernel]
            stride_y, stride_x = geometry[:stride]
            dilation_y, dilation_x = geometry[:dilation]
            pad_top, pad_left = geometry[:pad]
            in_height = geometry[:in_height]
            in_width = geometry[:in_width]
            out_height = geometry[:out_height]
            out_width = geometry[:out_width]

            (out_height * out_width).times { |index| out[out_base + index] = bias }

            geometry[:channels].times do |channel|
              channel_base = in_base + (channel * in_height * in_width)
              channel_weight = weight_base + (channel * kernel_height * kernel_width)

              kernel_height.times do |kernel_y|
                kernel_width.times do |kernel_x|
                  weight[channel_weight + (kernel_y * kernel_width) + kernel_x].then do |value|
                    unless value.zero?
                      accumulate(
                        out,
                        out_base,
                        input,
                        channel_base,
                        value,
                        [(kernel_y * dilation_y) - pad_top, (kernel_x * dilation_x) - pad_left],
                        [in_height, in_width, out_height, out_width],
                        [stride_y, stride_x],
                      )
                    end
                  end
                end
              end
            end
          end

          # Adds `value` times the input window one kernel offset names to the
          # output plane, over the output positions whose window is in bounds.
          def accumulate(out, out_base, input, in_base, value, offset, extents, strides)
            offset_y, offset_x = offset
            in_height, in_width, out_height, out_width = extents
            stride_y, stride_x = strides

            first_y = first_covered(offset_y, stride_y)
            last_y = [out_height - 1, (in_height - 1 - offset_y) / stride_y].min
            first_x = first_covered(offset_x, stride_x)
            last_x = [out_width - 1, (in_width - 1 - offset_x) / stride_x].min

            out_y = first_y
            while out_y <= last_y
              out_index = out_base + (out_y * out_width) + first_x
              last_index = out_base + (out_y * out_width) + last_x
              in_index = in_base +
                (((out_y * stride_y) + offset_y) * in_width) +
                offset_x +
                (first_x * stride_x)

              while out_index <= last_index
                out[out_index] += value * input[in_index]
                out_index += 1
                in_index += stride_x
              end

              out_y += 1
            end
          end

          # One channel's max pooling. A window that reaches outside the input
          # sees only the values that are in bounds, as ONNX's implicit padding
          # with negative infinity does.
          def pool_plane(out, out_base, input, in_base, geometry)
            kernel_height, kernel_width = geometry[:kernel]
            stride_y, stride_x = geometry[:stride]
            dilation_y, dilation_x = geometry[:dilation]
            pad_top, pad_left = geometry[:pad]
            in_height = geometry[:in_height]
            in_width = geometry[:in_width]

            geometry[:out_height].times do |out_y|
              geometry[:out_width].times do |out_x|
                best = -Float::INFINITY

                kernel_height.times do |kernel_y|
                  ((out_y * stride_y) + (kernel_y * dilation_y) - pad_top).then do |in_y|
                    if in_y >= 0 && in_y < in_height
                      kernel_width.times do |kernel_x|
                        ((out_x * stride_x) + (kernel_x * dilation_x) - pad_left).then do |in_x|
                          if in_x >= 0 && in_x < in_width
                            best = [best, input[in_base + (in_y * in_width) + in_x]].max
                          end
                        end
                      end
                    end
                  end
                end

                out[out_base + (out_y * geometry[:out_width]) + out_x] = best
              end
            end
          end

          # The width of a right-hand matrix, which its `transB` flag may have
          # stored the other way round.
          def columns_of(tensor, flip)
            if flip.zero?
              tensor.shape.last
            else
              tensor.shape.first
            end
          end

          # The height of a right-hand matrix, as the multiplication sees it.
          def inner_of(tensor, flip)
            if flip.zero?
              tensor.shape.first
            else
              tensor.shape.last
            end
          end

          # A matrix, transposed when the flag says so.
          def transposed(tensor, flag)
            if flag.zero?
              tensor
            else
              transpose(tensor)
            end
          end

          def transpose(tensor)
            rows, columns = tensor.shape

            Tensor.filled([columns, rows], 0.0).then do |output|
              rows.times do |row|
                columns.times do |column|
                  output.data[(column * rows) + row] = tensor.data[(row * columns) + column]
                end
              end

              output
            end
          end

          def multiply_into(out, left, right, rows, inner, columns, alpha)
            rows.times do |row|
              out_row = row * columns
              left_row = row * inner

              inner.times do |index|
                (alpha * left[left_row + index]).then do |value|
                  unless value.zero?
                    right_row = index * columns
                    column = 0
                    while column < columns
                      out[out_row + column] += value * right[right_row + column]
                      column += 1
                    end
                  end
                end
              end
            end
          end

          # The same product with the right-hand matrix stored transposed, one
          # row of it per output column. Walking it that way reads both operands
          # forwards instead of transposing a thousand rows of weights on every
          # call.
          def multiply_rows_into(out, left, right, rows, inner, columns, alpha)
            rows.times do |row|
              left_row = row * inner
              out_row = row * columns
              column = 0

              while column < columns
                right_row = column * inner
                total = 0.0
                index = 0

                while index < inner
                  total += left[left_row + index] * right[right_row + index]
                  index += 1
                end

                out[out_row + column] = alpha * total
                column += 1
              end
            end
          end

          # Adds `beta` times the bias to every row. ONNX broadcasts the bias,
          # which for this engine means a per-column vector or a single value.
          def add_bias(out, bias, rows, columns, beta)
            stride = 1
            if bias.size == 1
              stride = 0
            end

            rows.times do |row|
              out_row = row * columns

              columns.times do |column|
                out[out_row + column] += beta * bias.data[column * stride]
              end
            end
          end

          def resolve_shape(dims, input, allowzero)
            sized = dims.each_with_index.map do |dim, axis|
              if dim.zero? && allowzero.zero?
                input.shape[axis]
              else
                dim
              end
            end

            sized.map do |dim|
              if dim.negative?
                input.size / sized.reject(&:negative?).inject(1, :*)
              else
                dim
              end
            end
          end
      end
    end
  end
end
