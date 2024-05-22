# frozen_string_literal: true

# TODO: Generate TOC automatically if there are more than 3 h2s

# String helpers
class String
  def sanitized
    filename = dup
    filename.strip!
    filename.gsub!(/ +/, '_')
    filename.gsub!(%r{^.*(\\|/)}, '')
    filename.gsub!(/[^0-9A-Za-z.\-_]/, '')
    filename
  end

  def symbolify_symbols
    content = dup
    content.gsub!(/&#8592;/, '←')
    content.gsub!(/&#8593;/, '↑')
    content.gsub!(/&#8594;/, '→')
    content.gsub!(/&#8595;/, '↓')
    content.gsub!(/&#8598;/, '↖')
    content.gsub!(/&#8600;/, '↘')
    content.gsub!(/&#8670;/, '⇞')
    content.gsub!(/&#8671;/, '⇟')
    content.gsub!(/&#8677;/, '⇥')
    content.gsub!(/&#8679;/, '⇧')
    content.gsub!(/&#8963;/, '⌃')
    content.gsub!(/&#8984;/, '⌘')
    content.gsub!(/&#8996;/, '⌅')
    content.gsub!(/&#8997;/, '⌥')
    content.gsub!(/&#8998;/, '⌦')
    content.gsub!(/&#9003;/, '⌫')
    content.gsub!(/&#9099;/, '⎋')
    content.gsub!(/&#9166;/, '↩')
    content
  end

  def symbolify_symbols!
    replace symbolify_symbols
  end

  def textify_symbols
    content = dup
    content.gsub!(/(⌘|&#8984;)/, 'Cmd-')
    content.gsub!(/(⌥|&#8997;)/, 'Opt-')
    content.gsub!(/(⌃|&#8963;)/, 'Ctrl-')
    content.gsub!(/(⇧|&#8679;)/, 'Shift-')
    content.gsub!(/(⎋|&#9099;)/, 'Esc')
    content.gsub!(/(↑|&#8593;)/, 'Up Arrow')
    content.gsub!(/(↓|&#8595;)/, 'Down Arrow')
    content.gsub!(/(←|&#8592;)/, 'Left Arrow')
    content.gsub!(/(→|&#8594;)/, 'Right Arrow')
    content.gsub!(/▸/, '>')
    content
  end

  def textify_symbols!
    replace textify_symbols
  end

  def replace_with_entity
    case strip.downcase
    when /^apple$/
      '&#63743;'
    when /^(comm(and)?|cmd|clover)$/
      '&#8984;'
    when /^(cont(rol)?|ctl|ctrl)$/
      '&#8963;'
    when /^(opt(ion)?|alt)$/
      '&#8997;'
    when /^shift$/
      '&#8679;'
    when /^tab$/
      '&#8677;'
    when /^caps(lock)?$/
      '&#8682;'
    when /^eject$/
      '&#9167;'
    when /^return$/
      '&#9166;'
    when /^enter$/
      '&#8996;'
    when /^(del(ete)?|back(space)?)$/
      '&#9003;'
    when /^fwddel(ete)?$/
      '&#8998;'
    when /^(esc(ape)?)$/
      '&#9099;'
    when /^r(ight)?$/
      '&#8594;'
    when /^l(eft)?$/
      '&#8592;'
    when /^up?$/
      '&#8593;'
    when /^d(own)?$/
      '&#8595;'
    when /^pgup$/
      '&#8670;'
    when /^pgdn$/
      '&#8671;'
    when /^home$/
      '&#8598;'
    when /^end$/
      '&#8600;'
    when /^clear$/
      '&#8999;'
    when /^gear$/
      '&#9881;'
    else
      "{{#{self}}}"
    end
  end

  def modifier?
    self =~ /\{\{(comm(and)?|cmd|clover|shift|cont(rol)?|ctl|ctrl|opt(ion)?|alt)\}\}/i
  end

  # separate a key combination into separate kbd tags
  def format_kbd
    if self =~ /(\{\{[a-z]+\}\})+[A-Z0-9[:punct:]=]/i # modifier combo
      keys = scan(/(\{\{[a-z]+\}\}|[a-z0-9[:punct:]=])/i)
      keys.map!.with_index do |key, i|
        if key[0] =~ %r{^[/-]$} && i < (keys.length - 1)
          key[0]
        elsif key[0].modifier?
          %(<kbd class="modifierkey">#{key[0]}</kbd>)
        else
          %(<kbd>#{key[0].upcase}</kbd>)
        end
      end
      %(<span class="keycombo">#{keys.join('')}</span>)
    else
      classes = 'single'
      # classes += " modifierkey" if self.modifier?
      %(<kbd class="#{classes}">#{self}</kbd>)
    end
  end

  def format_kbd_pdf
    if self =~ /(\{\{[a-z]+\}\})+[A-Z0-9[:punct:]=]/i # modifier combo
      keys = scan(/(\{\{[a-z]+\}\}|[a-z0-9[:punct:]=])/i)
      keys.map!.with_index do |key, i|
        if key[0] =~ %r{^[/-]$} && i < (keys.length - 1)
          key[0]
        elsif key[0].modifier?
          key[0]
        else
          key[0].upcase
        end
      end
      %(`#{keys.join('')}`)
    else
      %(`#{self}`)
    end
  end

  def table_of_contents(opts = {})
    opts[:force] ||= false
    opts[:level] ||= 2

    headers = scan(/^(\#{#{opts[:level]}}(?!#))\s*(.*?)(\s*#+)?$/)
    return unless headers.length > 3 || opts[:force]

    output = []

    min = if opts[:level] =~ /(\d),(\d)/
            Regexp.last_match(1).to_i
          else
            opts[:level].to_i
          end

    headers.each do |h|
      title = h[1]
      id = ''

      hlevel = h[0].length - min

      title.gsub!(/#+/, '')
      title.strip!
      if title =~ /\[(.*?)\]$/
        id = Regexp.last_match(1).strip
        title.sub!(/\s*\[.*?\]$/, '')
      else
        id = title.gsub(/[^a-z0-9\-.]/i, '').downcase
      end
      output.push(%(#{"\t" * hlevel}* [#{title}](##{id})))
    end
    %(\n<nav id="sectiontoc" aria-label="Page contents" class="uk-width-full">\n\n#{output.join("\n")}\n\n</nav>\n\n)
  end

  def render_liquid(pdf: false)
    if pdf.to_s == 'marked'
      marked = true
      pdf = false
    end
    out = dup
    # Remove CriticMarkup Comments
    out.gsub!(/\{>>.*?<<\}/m, '')

    # Replace {% block [params] %}content{% endblock %}
    out.gsub!(/(?mi)\{%\s*(\S+)\s*(.*?)\s*%\}(.*?)\{%\s*end\1\s*%\}/m) do
      m = Regexp.last_match
      directive = m[1].strip
      params = m[2]
      content = m[3]

      output = ''

      # {% apponly p %}A paragraph that will show up only in the in-app
      # browser{% endapponly %}
      if directive =~ /(apponly|browseronly|class)/i
        padding = ''
        if directive == 'class'
          tag = 'span'
          classes = params.strip
        else
          tag = params.length.positive? ? params.strip : 'span'
          classes = directive
          padding = "\n\n" if tag =~ /div/
        end
        output = %(<#{tag} class="#{classes}">#{padding}#{content}#{padding}</#{tag}>)
      # {% notes %}some notes about this section{% endnotes %}
      elsif directive =~ /(notes?|comment|todo|fixme)/
        output = ''
      else
        output = content
      end

      output
    end

    # Replace single {% tag [params] %} directives
    out.gsub!(/\{% *(\S+) +(.*?) *%\}/) do
      m = Regexp.last_match
      directive = m[1]
      args = m[2].strip
      # {% prefspane General %}
      if directive =~ /prefs?pane/i && (pdf || marked)
        %(<span class="appmenu">**Preferences**▸[**#{args}**](preferences-#{args.downcase.gsub(/ /, '-')}.html) pane</span>)
      elsif directive =~ /prefs?pane/i && !pdf && !marked
        %(<span class="appmenu">**Preferences**▸[**#{args}**](#prefs#{args.downcase.gsub(/ /, '-')}) pane</span>)
      # {% kbd {{cmd}}S %}
      elsif directive =~ /kbd/i
        pdf ? args.format_kbd_pdf : args.format_kbd
      # {% appmenu File,Save ({{cmd}}S) %}
      elsif directive =~ /(app)?menu/
        kbd = ''
        if args =~ /\s+\((.*?)\)$/
          m = Regexp.last_match
          kbd = pdf ? " (#{m[1].format_kbd_pdf})" : " (#{m[1].format_kbd})"
          args.sub!(/\s+\((.*?)\)$/, '')
        end

        segs = args.split(/,/)
        toplevel = segs.slice!(0)

        res = %(<span class="appmenu">**#{toplevel}**)
        if !pdf
          segs.each do |seg|
            res += %(▸#{seg.strip})
          end
        else
          segs.each do |seg|
            res += %( *#{seg.strip}*)
          end
        end
        res + "</span>#{kbd}"

      elsif directive =~ /(notes?|comment|todo|fixme)/
        ''
      else
        m[0]
      end
    end

    if !pdf && !marked
      out.gsub!(/\{\{ *toc(?: [\d,]+)? *\}\}/i, '')
    elsif out =~ /\{\{ *toc( [1-6](,[2-6])?)? *\}\}/i
      out.gsub!(/\{\{ *toc(?: ([1-6](,[2-6])?))? *\}\}/i) do
        m = Regexp.last_match
        lvl = m[1] || 2
        out.table_of_contents({ force: true, level: lvl })
      end
    else
      toc = out.table_of_contents
      out.sub!(/^## /, "#{toc}\n\n## ") unless toc.nil?
    end

    # Replace {{insertions}}
    out.gsub!(/\{\{(.*?)\}\}/) do
      Regexp.last_match(1).strip.replace_with_entity
    end
    out
  end
end

if __FILE__ == $PROGRAM_NAME
  input = DATA.read
  puts input.render_liquid
end

__END__
# <%= @title %>

{>>A critic comment BT - 2019-05-19<<}

{>>A multiline

  critic comment BT - 2019-05-19<<}

A little bit of intro text.

## Section one

Choose "Validate all links" (shortcut {% kbd {{ctrl}}{{cmd}}L %}) from the Gear menu or the right click menu. All remote links in the document will be checked, and the results are displayed in a popup. Clicking a link in the popup will scroll to and highlight its respective link in the document.

{% todo test stuff %}

{% fixme %}
- some other stuff
- I need to do
- when I get a chance
{% endfixme %}

You can quickly re-open the last file you were viewing with {%kbd {{shift}}{{cmd}}R%}. There are a lot of other keyboard shortcuts, too. If you care to learn them, you can find a chart by clicking the Special Features link in the sidebar.

Save HTML with {% appmenu File,Export,Save HTML %}

## Section two [secttwo]

{% apponly div %}
*A paragraph to appear only [when run](https://brettterpstra.com) native.*
{% endapponly %}

{% browseronly %}A paragraph to appear only when run in a browser.{% endbrowseronly %}

### Subsection Uno ### [subsecuno]

{% note %}
The above should only have rendered as a span.
{% endnote %}

A paragraph containing {% apponly b %}a section for app only{% endapponly %}{% browseronly strong %}a section for browser only.{% endbrowseronly %}

### Subsection dos ###

{% class class1 class2 %}Valid urls may be hidden from the popup with the "Hide Valid" button at the top of it. This will show only urls that have returned an error status.{% endclass %}

#### Let's go real deep here

Pressing {% class class1 class2 %}Escape{%endclass%} will hide the validation results. They can be revealed again using {% kbd {{ctrl}}{{cmd}}L %} or the Gear menu.

## Validating Notes

Validating automatically {%note this should be removed completely %}

Turn on "Automatically validate URLs on update" in the Preview preferences (or at the bottom of the link validation popup). When the document loads, contained links will be tested in background. A dialog will only show if there are errors.

To disable the popup, turn it off in preferences, or uncheck the box at the bottom of the popup window.

## Validating Notes 2

Trigger autoscroll by pressing {% kbd s %}. This will begin scrolling forward through the document at the default speed.

An indicator at the bottom left will show you the current speed. The speed can be adjusted with the up and down arrows, and {% kbd {{shift}}{{up}}/{{down}} %} will speed it up and slow it down in larger increments.

{% kbd Space %} will pause and play as you scroll.

Pressing {% kbd S %} (Shift-s) while scrolling will reverse the scroll direction.

hold down Option-Command ({% kbd {{opt}}{{cmd}} %}) to open
