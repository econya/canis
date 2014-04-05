# ------------------------------------------------------------ #
#         File: chunk.rb 
#  Description: 
#       Author: jkepler http://github.com/mare-imbrium/canis/
#         Date: 07.11.11 - 12:31 
#  Same as Ruby's License (http://www.ruby-lang.org/LICENSE.txt)
#  Last update: 2013-04-01 13:38
# ------------------------------------------------------------ #
#

module Canis
  module Chunks
    extend self
    class Chunk

      # color_pair of associated text
      # text to print
      # attribute of associated text
      #attr_accessor :color, :text, :attrib
      attr_reader :chunk

      def initialize color, text, attrib
        @chunk = [ color, text, attrib ]
        #@color = color
        #@text  = text
        #@attrib = attrib
      end
      def color
        @chunk[0]
      end
      def text
        @chunk[1]
      end
      def attrib
        @chunk[2]
      end
    end

    # consists of an array of chunks and corresponds to a line
    # to be printed.
    class ChunkLine

      # an array of chunks
      attr_reader :chunks

      def initialize arr=nil
        @chunks = arr.nil? ? Array.new : arr
      end
      def <<(chunk)
        raise ArgumentError, "Chunk object expected. Received #{chunk.class} " unless chunk.is_a? Chunk
        @chunks << chunk
      end
      alias :add :<<
      def each &block
        @chunks.each &block
      end

      # returns length of text in chunks
      def row_length
        result = 0
        @chunks.each { |e| result += e.text.length }
        return result
      end
      # returns match for str in this chunk
      # added 2013-03-07 - 23:59 
      def index str
        result = 0
        @chunks.each { |e| txt = e.text; 
          ix =  txt.index(str) 
          return result + ix if ix
          result += e.text.length 
        }
        return nil
      end
      alias :length :row_length
      alias :size   :row_length

      # return a Chunkline containing only the text for the range requested
      def substring start, size
        raise "substring not implemented yet"
      end
      def to_s
        result = ""
        @chunks.each { |e| result << e.text }
        result
      end

      # added to take care of many string methods that are called.
      # Callers really don't know this is a chunkline, they assume its a string
      # 2013-03-21 - 19:01 
      def method_missing(sym, *args, &block)
        self.to_s.send sym, *args, &block
      end
    end
    class ColorParser
      def initialize cp
        color_parser cp
        @color_pair = $datacolor
        @attrib     = FFI::NCurses::A_NORMAL
        @color_array = [:white]
        @bgcolor_array = [:black]
        @attrib_array = [@attrib]
        @color_pair_array = [@color_pair]
        @color = :white
        @bgcolor = :black
      end
      #
      # Takes a formatted string and converts the parsed parts to chunks.
      #
      # @param [String] takes the entire line or string and breaks into an array of chunks
      # @yield chunk if block
      # @return [ChunkLine] # [Array] array of chunks
      # @since 1.4.1   2011-11-3 experimental, can change
      public
      def convert_to_chunk s, colorp=$datacolor, att=FFI::NCurses::A_NORMAL
        #require 'canis/core/include/chunk'

        @color_parser ||= get_default_color_parser()
        ## defaults
        color_pair = @color_pair
        attrib = @attrib
        #res = []
        res = ChunkLine.new
        color = @color
        bgcolor = @bgcolor
        # stack the values, so when user issues "/end" we can pop earlier ones

        @color_parser.parse_format(s) do |p|
          case p
          when Array
            ## got color / attrib info, this starts a new span

            #color, bgcolor, attrib = *p
            lc, lb, la = *p
            if la
              @attrib = get_attrib la
            end
            if lc || lb
              @color = lc ? lc : @color_array.last
              @bgcolor = lb ? lb : @bgcolor_array.last
              @color_array << @color
              @bgcolor_array << @bgcolor
              @color_pair = get_color($datacolor, @color, @bgcolor)
            end
            @color_pair_array << @color_pair
            @attrib_array << @attrib
            #$log.debug "XXX: CHUNK start #{color_pair} , #{attrib} :: c:#{lc} b:#{lb} "
            #$log.debug "XXX: CHUNK start arr #{@color_pair_array} :: #{@attrib_array} "

          when :endcolor

            # end the current (last) span
            @color_pair_array.pop
            @color_pair = @color_pair_array.last
            @attrib_array.pop
            @attrib = @attrib_array.last
            #$log.debug "XXX: CHUNK end #{color_pair} , #{attrib} "
            #$log.debug "XXX: CHUNK end arr #{@color_pair_array} :: #{@attrib_array} "
          when :reset   # ansi has this
            # end all previous colors
            @color_pair = $datacolor # @color_pair_array.first
            @color_pair_array = [@color_pair]
            @attrib = FFI::NCurses::A_NORMAL #@attrib_array.first
            @attrib_array = [@attrib]
            @bgcolor_array = [@bgcolor_array.first]
            @color_array = [@color_array.first]

          when String

            ## create the chunk
            #$log.debug "XXX:  CHUNK     using on #{p}  : #{@color_pair} , #{@attrib} " # 2011-12-10 12:38:51

            #chunk =  [color_pair, p, attrib] 
            chunk = Chunk.new @color_pair, p, @attrib
            if block_given?
              yield chunk
            else
              res << chunk
            end
          end
        end # parse
        return res unless block_given?
      end
      def get_default_color_parser
        require 'canis/core/util/colorparser'
        @color_parser || DefaultColorParser.new
      end
      # supply with a color parser, if you supplied formatted text
      public
      def color_parser f
        $log.debug "XXX:  color_parser setting in CP to #{f} "
        if f == :tmux
          @color_parser = get_default_color_parser()
        elsif f == :ansi
          require 'canis/core/util/ansiparser'
          @color_parser = AnsiParser.new
        else
          @color_parser = f
        end
      end
    end # class
  end
end
