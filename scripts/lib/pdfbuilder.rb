class PDFBuilder
	include Utils
	attr_accessor :config, :filelist, :basefolder, :norepeat, :norepeatlinks, :output
	def initialize

		@basefolder = File.join(File.dirname(__FILE__),'..')
		Dir.chdir(@basefolder)
		config_file = File.expand_path(@basefolder + "/config.yaml")

		@config = Utils.load_config(config_file)

		@filelist = file_list

		@norepeat = []
		@norepeatlinks = []

		build_help
		generate_compiled
	end

	def generate_compiled
		Utils.update_status("Building Compiled Document",{:last => true})

		template = ERB.new(Utils.load_template("#{@basefolder}/compile_template.html"))

		section_template = ERB.new <<-SECTIONTEMPLATE
## <%= @section_title %>

<%= @lessons %>

SECTIONTEMPLATE

		lesson_template = ERB.new <<-LESSONTEMPLATE

---

<<[<%= @filename %>.md]
LESSONTEMPLATE

		@main_title = @config["Title"]

		@sections = ""
		@config["Sections"].each do |section|
			@section_title = section["title"]
			@section_folder = section["folder"]
			@section_class = section_folder.downcase.gsub(/[-_]/,'')
			@lessons = ""
			section["pages"].each do |page|
				@title = page["title"]
				@filename = page["file"]
				@page_class = filename.downcase.gsub(/[-_]/,'')
				@lessons += lesson_template.result(binding)
			end
			@sections += section_template.result(binding)
		end

		outfile = File.new(@basefolder+'/content'+@settings[:pdfext]+'/Compiled.md', "w+")
		outfile.write(template.result(binding))
		# outfile.write(content)
		outfile.close
	end

	def convert_links(text)
		output = []
		links = text.scan(/\]\(([^\)]+)\)/)
		refs = text.scan(/^\s{0,3}\[([^\]]+)\]: (\S+)( .*)?$/)
		lines = text.split("\n")
		bottom = lines[0..-1].join("\n").gsub(/^\s{0,3}\[([^\]]+)\]: (\S+)( .*\n)?$/,'')

		refs.each {|ref|
			name = ref[0]
			next if @norepeatlinks.include? ref[1]
			while @norepeat.include? name
				if name =~ / ?[0-9]$/
					name.next!
				else
					name = name + " 2"
				end
			end
			tail = ref[2].nil? ? '' : ref[2].to_s
			output << {'orig' => ref[0], 'title' => name, 'link' => ref[1]+tail}
			@norepeat.push name
			@norepeatlinks.push ref[1]
		}

		links.each {|url|
			next if @norepeatlinks.include? url[0]
			if url[0] =~ /^http/
				domain = url[0].match(/https?:\/\/([^\/]+)/)
				parts = domain[1].split('.')
				name = case parts.length
					when 1
						parts[0]
					when 2
						parts[0]
					else
						parts[1]
				end
			elsif url[0] !~ /^[\/~]/
				name = File.basename(url[0]).split('.')[0]
			else
				name = 'Unknown'
			end
			while @norepeat.include? name
				if name =~ / ?[0-9]$/
					name.next!
				else
					name = name + " 2"
				end
			end
			output << {'orig' => url[0], 'title' => name, 'link' => url[0] }
			@norepeat.push name
			@norepeatlinks.push url[0]
		}
		output = output.sort {|a,b| a['title'] <=> b['title']}
		o = []
		output.each_with_index { |x,i|
			o.push("[#{x['title']}]: #{x['link']}")
			bottom = bottom.gsub(/\((#{x['orig']}|#{x['link']})\)/,"[#{x['title']}]").gsub(/\[#{x['orig']}\]/,"[#{x['title']}]")
		}
		return bottom + "\n\n#{o.join("\n")}\n"
	end

	def generate_page(section_folder,page)

		Utils.update_status("Processing page: ------------------------------#{page['title']}")


		infile = "#{@basefolder}/content#{@settings[:debug]}/#{page['file']}.md"
		outfile = "#{@basefolder}/content#{@settings[:pdfext]}/#{page['file']}.md"

		title = page["title"] + " [" + page["file"].gsub(/_/,'').downcase + "]"
		text = Utils.remove_todos(Utils.load_template(infile).gsub(/<%= @title %>/,title))

		# Move headers two units down the hierarchy
		lines = text.split("\n")
		first_headline = ""
		first_headline_level = 0
		line_counter = 0
		while first_headline.empty? && line_counter < lines.length
			if lines[line_counter] =~ /^#+\s/
				first_headline = lines[line_counter]
				first_headline_level = first_headline.split(' ')[0].length
			end
			line_counter +=  1
		end
		text.gsub!(/^#/,'###') if first_headline_level == 1 && first_headline =~ /^#+\s/

		# Fix wiki links
		Utils.update_status("Fixing wiki links")
		text.gsub!(/\]\(\[\[(.*?)(#.*?)?\]\]\)/) {|match|
			if match =~ /\]\(\[\[(.*?)(#.*?)?\]\]\)/
				"](#{$1}.html#{$2})"
			end
		}
		text.gsub!(/: \[\[(.*?)(#.*?)?\]\]/) {|match|
			if match =~ /: \[\[(.*?)(#.*?)?\]\]/
				": #{$1}.html#{$2}"
			end
		}

		# Fix image references
		change_counter = 0
		text.scan(/\[(\d+)\]:\s+(.*?)\.(jpg|png)/).each { |match|
			change_counter += 1
			text.gsub!(/\[#{match[0]}\]/,"[#{match[1].gsub(/images\//,'')}]")
		}
		Utils.update_status("-- #{change_counter} image changes")

		if text.scan(/\[(.*?)\](:\s+(.*)$|\(.*?\))/).length > 0
			# convert inline links to refs
			text = convert_links(text)

			# Fix url references

			change_counter = 0
			text.scan(/^\s*\[(\d+)\]:\s+(.*)$/).each { |match|
				change_counter += 1

				if match[1] =~ /^http/
					domain = match[1].match(/https?:\/\/([^\/]+)/)
					parts = domain[1].split('.')
					name =	case parts.length
						when 1
							parts[0]
						when 2
							parts[0]
						else
							parts[1]
					end
				elsif match[1] =~ /\/?([^\/]+)\/?$/
					name = $1.gsub(/([^\.]+)\.[^\.]*$/,"\\1")
				else
					name = "Unknown"
				end

				while @norepeat.include? name
					if name =~ / ?[0-9]$/
						name.next!
					else
						name = name + " 2"
					end
				end
				@norepeat.push(name)
				text.gsub!(/\[#{match[0]}\]/,"[#{name}]")
			}

			Utils.update_status("-- #{change_counter} url reference changes")
		else
			Utils.update_status("-- NO LINKS FOUND")
		end

		# Fix internal urls
		text.gsub!(/\](\(|: ).*?\.html(#.*?)?(\)|$)/) { |match|
			if match =~ /\]: (.*?)\.html(#.*)?$/
				if $2.nil?
					"]: ##{$1.gsub(/_/,'').downcase}"
				else
					"]: #{$2}"
				end
			elsif match =~ /\]\((.*?)\.html(#.*?)?\)/
				"](#{$1}.html#{$2})"
			end
		}

		Utils.update_status("Adding sizes to images")
		text.scan(/\[(.*?)\]:\s*(?!http)(.*?\.(jpg|png|gif|svg))\s*$/).each {|image_match|
			image_id = image_match[0]
			image_path = image_match[1]
			if image_path =~ /^[\/~]/ # absolute path
				image_path = File.expand_path(image_path)
			else
				image_path = File.expand_path("#{@basefolder}/content#{@settings[:debug]}/#{image_path}")
			end
			width = %x{sips -g pixelWidth "#{image_path}"|tail -n1|awk '{print $2}'}.strip
			height = %x{sips -g pixelHeight "#{image_path}"|tail -n1|awk '{print $2}'}.strip
			text.gsub!(/\[#{image_id}\]:.*?\.(jpg|png|gif|svg)/,"[#{image_id}]: #{image_match[1]} width=#{width}px height=#{height}px")
		}

		fh = File.new(outfile, "w+")
		fh.puts(text)
		fh.close
	end

	def build_help
		@config["Sections"].each do |section|
			folder = section["folder"]
			section["pages"].each do |page|
				generate_page(folder,page)
			end
		end
		Utils.update_status("Copying images to content#{@settings[:pdfext]}/images")
		FileUtils.copy_entry("#{@basefolder}/content#{@settings[:debug]}/images","#{@basefolder}/content#{@settings[:pdfext]}/images")
		FileUtils.copy_entry("#{@basefolder}/marked_icon_lg.png","#{@basefolder}/content#{@settings[:pdfext]}/images/marked_icon_lg.png")
	end

	def file_list
		list = {}
		# # debugging
		# return {'Exporting' => "Exporting"}
		@config["Sections"].each do |section|
			folder = section['folder']
			section['pages'].each do |page|
				list[page['file']] = "#{folder}/#{page['file']}"
			end
		end
		list
	end

end
