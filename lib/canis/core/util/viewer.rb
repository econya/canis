#require 'canis/core/widgets/rtextview'
require 'canis/core/widgets/textpad'
require 'fileutils'

# A file or array viewer.
#
# CHANGES
#   - 2014-04-09 - 00:58 changed textview to textpad 
# NOTE: experimental, not yet firmed up
# If you use in application, please copy to some application folder in case i change this.
# Can be used for print_help_page
# TODO: add vi_keys here
# SUGGESTIONS WELCOME.

module Canis
  # a data viewer for viewing some text or filecontents
  # view filename, :close_key => KEY_ENTER
  # send data in an array
  # view Array, :close_key => KEY_ENTER, :layout => [0,0,23,80]
  # when passing layout reserve 4 rows for window and border. So for 2 lines of text
  # give 6 rows.
  class Viewer
    # @param filename as string or content as array
    # @yield textview object for further configuration before display
    # NOTE: i am experimentally yielding textview object so i could supress borders
    # just for kicks, but on can also bind_keys or events if one wanted.
    def self.view what, config={} #:yield: textview
      case what
      when String # we have a path
        content = _get_contents(what)
      when Array
        content = what
      else
        raise ArgumentError, "Viewer: Expecting Filename or Contents (array), but got #{what.class} "
      end
      wt = 0 # top margin
      wl = 0 # left margin
      wh = Ncurses.LINES-wt # height, goes to bottom of screen
      ww = Ncurses.COLS-wl  # width, goes to right end
      wt, wl, wh, ww = config[:layout] if config.has_key? :layout

      fp = config[:title] || ""
      pf = config.fetch(:print_footer, true)
      ta = config.fetch(:title_attrib, 'bold')
      fa = config.fetch(:footer_attrib, 'bold')
      type = config[:content_type]

      layout = { :height => wh, :width => ww, :top => wt, :left => wl } 
      v_window = Canis::Window.new(layout)
      v_form = Canis::Form.new v_window
      colors = Ncurses.COLORS
      back = :blue
      back = 235 if colors >= 256
      blue_white = get_color($datacolor, :white, back)
      #blue_white = Canis::Utils.get_color($datacolor, :white, 235)
      textview = TextPad.new v_form do
        name   "Viewer" 
        row  0
        col  0
        width ww
        height wh-0 # earlier 2 but seems to be leaving space.
        title fp
        title_attrib ta
        print_footer pf
        footer_attrib fa
        #border_attrib :reverse
        border_color blue_white
      end
      # why multibuffers ?
      require 'canis/core/include/multibuffer'
      textview.extend(Canis::MultiBuffers)

      t = textview
      t.bind_key('<', 'move window left'){ f = t.form.window; c = f.left - 1; f.hide; f.mvwin(f.top, c); f.show;
        f.reset_layout([f.height, f.width, f.top, c]); 
      }
      t.bind_key('>', 'move window right'){ f = t.form.window; c = f.left + 1; f.hide; f.mvwin(f.top, c); 
        f.reset_layout([f.height, f.width, f.top, c]); f.show;
      }
      t.bind_key('^', 'move window up'){ f = t.form.window; c = f.top - 1 ; f.hide; f.mvwin(c, f.left); 
        f.reset_layout([f.height, f.width, c, f.left]) ; f.show;
      }
      t.bind_key('V', 'move window down'){ f = t.form.window; c = f.top + 1 ; f.hide; f.mvwin(c, f.left); 
        f.reset_layout([f.height, f.width, c, f.left]); f.show;
      }
      # yielding textview so you may further configure or bind keys or events
      begin
        # why the add_content ?
      textview.set_content content, :content_type => type
      textview.add_content content, :content_type => type
      # the next can also be used to use formatted_text(text, :ansi)
      yield textview if block_given? 
      v_form.repaint
      v_window.wrefresh
      Ncurses::Panel.update_panels
      # allow closing using q and Ctrl-q in addition to any key specified
      #  user should not need to specify key, since that becomes inconsistent across usages
        while((ch = v_window.getchar()) != ?\C-q.getbyte(0) )
          break if ch == config[:close_key] || ch == ?q.ord || ch == 2727 # added double esc 2011-12-27 
          # if you've asked for ENTER then i also check for 10 and 13
          break if (ch == 10 || ch == 13) && config[:close_key] == KEY_ENTER
          v_form.handle_key ch
          v_form.repaint
        end
      rescue => err
          $log.error " VIEWER ERROR #{err} "
          $log.debug(err.backtrace.join("\n"))
          textdialog ["Error in viewer: #{err} ", *err.backtrace], :title => "Exception"
      ensure
        v_window.destroy if !v_window.nil?
      end
    end
    private
    def self._get_contents fp
      return "File #{fp} not readable"  unless File.readable? fp 
      return Dir.new(fp).entries if File.directory? fp
      case File.extname(fp)
      when '.tgz','.gz'
        cmd = "tar -ztvf #{fp}"
        content = %x[#{cmd}]
      when '.zip'
        cmd = "unzip -l #{fp}"
        content = %x[#{cmd}]
      when '.jar', '.gem'
        cmd = "tar -tvf #{fp}"
        content = %x[#{cmd}]
      when '.png', '.out','.jpg', '.gif','.pdf'
        content = "File #{fp} not displayable"
      when '.sqlite'
        cmd = "sqlite3 #{fp} 'select name from sqlite_master;'"
        content = %x[#{cmd}]
      else
        content = File.open(fp,"r").readlines
      end
    end
  end  # class

end # module
if __FILE__ == $PROGRAM_NAME
require 'canis/core/util/app'

App.new do 
  header = app_header "canis 1.2.0", :text_center => "Viewer Demo", :text_right =>"New Improved!", :color => :black, :bgcolor => :white, :attr => :bold 
  message "Press F1 to exit from here"

    Canis::Viewer.view(ARGV[0] || $0, :close_key => KEY_ENTER, :title => "Enter to close") do |t|
      # you may configure textview further here.
      #t.suppress_borders true
      #t.color = :black
      #t.bgcolor = :white
      # or
      #t.attr = :reverse
    end

end # app
end
