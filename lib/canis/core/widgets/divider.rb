require 'canis/core/util/app'
#include Ncurses # FFI 2011-09-8 
include Canis

# TODO : We can consider making it independent of objects, or allow for a margin so it does not write
# over the object. Then it will be always visible.
# TODO: if lists and tables, can without borders actually adjust then putting this independent
# would make even more sense, since it won't eat an extra line.
#
# @example
#     lb = list_box ....
#     rb = Divider.new @form, :parent => lb, :side => :right
#
# At a later stage, we will integrate this with lists and tables, so it will happen automatically.
#
# @since 1.2.0
module Canis
  class DragEvent < Struct.new(:source, :type); end

  # This is a horizontal or vertical bar (like a scrollbar), at present attached to a
  # widget that is focusable, and allows user to press arrow keys.
  # It highlights on focus, the caller can expand and contract components in a container
  # or even screen, based on arrow movements. This allows for a visual resizing of components.
  # @example
  #     lb = list_box ....
  #     rb = Divider.new @form, :parent => lb, :side => :right
  #
  # NOTE: since this can be deactivated, containers need to check focusable before passing
  # focus in
  #  2010-10-07 23:56 made focusable false by default. Add divider to
  #  FocusManager when creating, so F3 can be used to set focusable
  #  See rvimsplit.rb for example

  class Divider < Widget
    # row to start, same as listbox, required.
    dsl_property :row
    # column to start, same as listbox, required.
    dsl_property :col
    # how many rows is this (should be same as listboxes height, required.
    dsl_property :length
    # vertical or horizontal currently only VERTICAL
    dsl_property :side
    # initialize based on parent's values
    dsl_property :parent
    # which row is focussed, current_index of listbox, required.
    # how many total rows of data does the list have, same as @list.length, required.
    dsl_accessor :next_component  # 'next' bombing in dsl_accessor 2011-10-2 PLS CHANGE ELSEWHERE

    # TODO: if parent passed, we shold bind to ON_ENTER and get current_index, so no extra work is required.

    def initialize form, config={}, &block

      # setting default first or else Widget will place its BW default
      #@color, @bgcolor = ColorMap.get_colors_for_pair $bottomcolor
      super
      @height = 1
      @color_pair = get_color $datacolor, @color, @bgcolor
      @scroll_pair = get_color $bottomcolor, :green, :white
      #@window = form.window
      @editable = false
      # you can set to true upon creation, or use F3 on vimsplit to
      # toggle focusable
      @focusable = false
      @repaint_required = true
      @_events.push(:DRAG_EVENT)
      map_keys
      unless @parent
        raise ArgumentError, "row col and length should be provided" if !@row || !@col || !@length
      end
      #if @parent
        #@parent.bind :ENTER_ROW do |p|
          ## parent must implement row_count, and have a @current_index
          #raise StandardError, "Parent must implement row_count" unless p.respond_to? :row_count
          #self.current_index = p.current_index
          #@repaint_required = true  #requred otherwise at end when same value sent, prop handler
          ## will not be fired (due to optimization).
        #end
      #end
    end
    def map_keys
      if !defined? $deactivate_dividers
        $deactivate_dividers = false
      end
      # deactivate only this bar
      bind_key(?f) {@focusable=false; }
      # deactivate all bars, i've had nuff!
      bind_key(?F) {deactivate_all(true)}
    end

    ##
    # repaint the scrollbar
    # Taking the data from parent as late as possible in case parent resized, or 
    # moved around by a container.
    # NOTE: sometimes if this is inside another object, the divider repaints but then
    # is wiped out when that objects print_border is called. So such an obkect (e.g.
    # vimsplit) should call repaint after its has done its own repaint. that does mean
    # the repaint happens twice during movement
    def repaint
      woffset = 2
      coffset = 1
      if @parent
        woffset = 0 if @parent.suppress_borders
        @border_attrib ||= @parent.border_attrib
        case @side
        when :right
          @row = @parent.row+1
          @col = @parent.col + @parent.width - 0
          @length = @parent.height - woffset
        when :left
          @row = @parent.row+1
          @col = @parent.col+0 #+ @parent.width - 1
          @length = @parent.height - woffset
        when :top
          @row = @parent.row+0
          @col = @parent.col + @parent.col_offset #+ @parent.width - 1
          @length = @parent.width - woffset
        when :bottom
          @row = @parent.row+@parent.height-0 #1
          @col = @parent.col+@parent.col_offset #+ @parent.width - 1
          @length = @parent.width - woffset
        end
      else
        # row, col and length should be passed
      end
      my_win = @form ? @form.window : @target_window
      @graphic = my_win unless @graphic
      raise "graphic is nil in divider, perhaps form was nil when creating" unless @graphic
      return unless @repaint_required

      # first print a right side vertical line
      #bc = $bottomcolor  # dark blue
      bc = get_color($datacolor, :cyan, :black)
      bordercolor = @border_color || bc
      borderatt = @border_attrib || Ncurses::A_REVERSE
      if @focussed 
        bordercolor = $promptcolor || bordercolor
      end

      borderatt = convert_attrib_to_sym(borderatt) if borderatt.is_a? Symbol

      @graphic.attron(Ncurses.COLOR_PAIR(bordercolor) | borderatt)
      $log.debug " XXX DIVIDER #{@row} #{@col} #{@length} "
      case @side
      when :right, :left
        @graphic.mvvline(@row, @col, 1, @length)
      when :top, :bottom
        @graphic.mvhline(@row, @col, 1, @length)
      end
      @graphic.attroff(Ncurses.COLOR_PAIR(bordercolor) | borderatt)
      _paint_marker
      #alert "divider repaint at #{row} #{col} "

      @repaint_required = false
    end
    def convert_attrib_to_sym attr
      case attr
      when 'reverse'
        Ncurses::A_REVERSE
      when 'bold'
        Ncurses::A_BOLD
      when 'normal'
        Ncurses::A_NORMAL
      when 'blink'
        Ncurses::A_BLINK
      when 'underline'
        Ncurses::A_UNDERLINE
      else
        Ncurses::A_REVERSE
      end
    end
    # deactivate all dividers
    # The application has to provide a key or button to activate all
    # or just this one.
    def deactivate_all  tf=true
      $deactivate_dividers = tf
      @focusable = !tf
    end
    def handle_key ch
      # all dividers have been deactivated
      if $deactivate_dividers || !@focusable
        @focusable = false
        return :UNHANDLED
      end
      case @side
      when :right, :left
        case ch
        when KEY_RIGHT
          fire_handler :DRAG_EVENT, DragEvent.new(self, ch)
        when KEY_LEFT
          fire_handler :DRAG_EVENT, DragEvent.new(self, ch)
        else
          ret = process_key ch, self
          return ret if ret == :UNHANDLED
        end
        set_form_col
      when :top, :bottom
        case ch
        when KEY_UP
          fire_handler :DRAG_EVENT, DragEvent.new(self, ch)
        when KEY_DOWN
          fire_handler :DRAG_EVENT, DragEvent.new(self, ch)
        else
          ret = process_key ch, self
          return ret if ret == :UNHANDLED
        end
        set_form_col
      else
      end
      @repaint_required = true
      return 0
    end
    def on_enter
      if $deactivate_dividers || !@focusable
        @focusable = false
        return :UNHANDLED
      end
      # since it is over border of component, we need to repaint
      @focussed = true
      @repaint_required = true
      repaint
    end
    def on_leave
      @focussed = false
      @repaint_required = true
      repaint
      # TODO: we should review this since its not over the parent any longer
      if @parent
        # since it is over border of component, we need to clear
        @parent.repaint_required 
        # if we don't paint now, parent paints over other possible dividers
        @parent.repaint
      end
    end
    def set_form_row
      return unless @focusable
      r,c = rowcol
      setrowcol r, c
    end
    # set the cursor on first point of bar
    def set_form_col
      return unless @focusable
      # need to set it to first point, otherwise it could be off the widget
      r,c = rowcol
      setrowcol r, c
    end
    # is this a vertical divider
    def v?
      @side == :top || @side == :bottom
    end
    # is this a horizontal divider
    def h?
      @side == :right || @side == :left
    end
    private
    def _paint_marker  #:nodoc:
      r,c = rowcol
      if @focussed
        @graphic.mvwaddch r,c, Ncurses::ACS_DIAMOND
        if v?
          @graphic.mvwaddch r,c+1, Ncurses::ACS_UARROW
          @graphic.mvwaddch r,c+2, Ncurses::ACS_DARROW
        else
          @graphic.mvwaddch r+1,c, Ncurses::ACS_LARROW
          @graphic.mvwaddch r+2,c, Ncurses::ACS_RARROW
        end
      else
        #@graphic.mvwaddch r,c, Ncurses::ACS_CKBOARD
      end
    end
    ##
    ##
    # ADD HERE 
    end # class
end # module
if __FILE__ == $PROGRAM_NAME
  App.new do
    r = 5
    len = 20
    list = []
    0.upto(100) { |v| list << "#{v} scrollable data" }
    lb = list_box "A list", :list => list, :row => 2, :col => 2
    #sb = Scrollbar.new @form, :row => r, :col => 20, :length => len, :list_length => 50, :current_index => 0
    rb = Divider.new @form, :parent => lb, :side => :right
    rb.bind :DRAG_EVENT do |e|
      message "got an event #{e.type} "
      case e.type
      when KEY_RIGHT
        lb.width += 1
      when KEY_LEFT
        lb.width -= 1
      end
      lb.repaint_required
    end
    rb1 = Divider.new @form, :parent => lb, :side => :bottom
    rb.focusable(true)
    rb1.focusable(true)
    rb1.bind :DRAG_EVENT do |e|
      message " 2 got an event #{e.type} "
    end
    #hline :width => 20, :row => len+r
    #keypress do |ch|
      #case ch
      #when :down
        #sb.current_index += 1
      #when :up
        #sb.current_index -= 1
      #end
    #end
  end
end
