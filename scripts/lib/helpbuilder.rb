class HelpBuilder
	include Utils
	attr_accessor :config, :outfolder, :basefolder, :index, :version, :keywords, :filelist
	def initialize (deploy,build_index,scripts_only)

		@settings = DEFAULT_SETTINGS.dup
		@internal = ''
		@basefolder = File.join(File.dirname(__FILE__),'..')
		Dir.chdir(@basefolder)
		config_file = File.expand_path(@basefolder + "/config.yaml")

		@config = Utils.load_config(config_file)

		@main_title = @config["Title"]
		@main_logo = @config["Logo"]
		@main_css = @config["CSS"]
		@secondary_css = @config["CSS2"]

		@version = @config['Version'].to_s
		@help_outfolder = File.expand_path(@basefolder+"/"+@config["Title"]+".help")
		@outfolder = File.expand_path(@basefolder+"/"+@config["Title"]+".web")

		# @keywords = keyword_list
		@filelist = file_list
		@searchindex = []

		# Make storage directory if needed
		FileUtils.mkdir_p(@outfolder,:mode => 0755) unless File.exists? @outfolder
		FileUtils.mkdir_p(@help_outfolder,:mode => 0755) unless File.exists? @help_outfolder

		if scripts_only
			copy_dependencies
			run_deploy(deploy)
			Process.exit
		end

		generate_index_page
		generate_changelog

		@index = generate_index('../')
		build_help
		generate_marked_index
		generate_full_index if build_index
		generate_search_page
		copy_dependencies

		run_deploy(deploy)
	end

	def run_deploy(deploy=true)
		if deploy
			# Utils.update_status("Building Apple Help Index",{:last => true})
			# %x{hiutil -C -g -s en -m 3 -f "#{@help_outfolder}/#{@config["Title"]}.helpindex" "#{@help_outfolder}"}
			Utils.update_status("Deploying to #{@config['TargetProject']}",{:last => true})
			FileUtils.copy_entry(@help_outfolder,File.expand_path(@config["TargetProject"]))
			%x{touch "#{File.expand_path(@config["TargetProject"])}"}
		end
		Utils.update_status("Populating test project (#{@config["TestingProject"]})",{:last => true})
		FileUtils.copy_entry(@outfolder,File.expand_path(@config["TestingProject"]))
	end

	def generate_marked_index
		Utils.update_status("Generating Marked 2 index")
		output = ["# nvUltra Docs"]
		@config["Pages"].each_with_index do |page, i|
			output.push '{{content/' + page['file'] + '.md}}'
		end
		File.open(File.join(@basefolder,'index.md'), 'w') do |f|
			f.puts output.join("\n\n")
		end
	end

	def generate_search_json
		Utils.update_status("Generating search")
		out = {'pages' => @searchindex}
		out.to_json
	end

	def read_changelog
		# input = IO.read(File.expand_path("~/Dropbox/nvALT2.2/nvUltra release notes.md")).force_encoding('utf-8')
		input = IO.read(File.expand_path("content/changelog.md")).force_encoding('utf-8')

		input.gsub!(/^(nvUltra.*?(\d\.\d\.\d) \(.*?\)\n\-+)/m,"%%%%BREAK%%%%\n\\1")
		input.gsub!(/^(.*?)\n=+/m, "\n## \\1\n")

		updates = input.split(/%%%%BREAK%%%%/)

		out = "# nvUltra Changelog\n\n"

		updates.each do |update|
			m = update.match(/^nvUltra.*?(\d\.\d\.\d) \(([0-9.]+)\)\n\-+/)
			content = update.gsub(/^nvUltra.*?(\d\.\d\.\d) \(([0-9.]+)\)\n\-+/, '').strip
			unless m.nil?
				ver = "#{m[1]} (#{m[2]})"
				out += "### Version #{ver}\n\n<section>\n\n"
				out += content + "\n\n</section>\n\n"
			end
		end

		out
	end

	def generate_search_page
		Utils.update_status("Building Search")
		@sections = generate_index('./')
		template = ERB.new(Utils.load_template("#{@basefolder}/resources/search_template.html"))
		prefix = './'
		@subtitle = @config["Title"]
		@main_logo = @config["Logo"]
		@main_css = @config["CSS"]
		@secondary_css = @config["CSS2"]
		@searchjson = generate_search_json
		@title = @config['Title'] + " - Search"
		@section_class = "search"
		@page_class = "search"

		@prefix = './'
		File.open(@outfolder+'/search.html', "w+") do |out|
			out.puts(template.result(binding))
		end
		File.open(@help_outfolder+'/search.html', "w+") do |out|
			out.puts(template.result(binding))
		end
		File.open(@help_outfolder+'/search.json', 'w+') do |f|
			f.puts @searchjson
		end
	end

	def generate_changelog
		Utils.update_status("Building Changelog")

		@sections = generate_index('./')

		template = ERB.new(Utils.load_template("#{@basefolder}/resources/template.html"))
		help_template = ERB.new(Utils.load_template("#{@basefolder}/resources/template_internal.html"))
		prefix = './'
		@subtitle = @config["Title"]

		changelog = read_changelog
		@title = @config['Title'] + " - Changelog"
		@section_class = "changelog"
		@page_class = "changelog"
		text = ERB.new(changelog).result(binding)

		@content = %x{echo #{Shellwords.escape(text)}|/usr/local/bin/multimarkdown}
		prefix = './'
		File.open(@outfolder+'/changelog.html', "w+") do |outfile|
			outfile.puts(template.result(binding))
		end
		File.open(@help_outfolder+'/changelog.html', "w+") do |outfile|
			outfile.puts(help_template.result(binding))
		end
	end


	def generate_index_page
		Utils.update_status("Building Home Page")
		@sections = generate_index('./')
		template = ERB.new(Utils.load_template("#{@basefolder}/resources/template.html"))
		help_template = ERB.new(Utils.load_template("#{@basefolder}/resources/template_internal.html"))

		prefix = './'
		@subtitle = @main_title

		infile = @basefolder+"/content#{@settings[:debug]}/"+@config['MDIndex'] + ".md"
		@title = @config['Title']
		@section_class = "gettingstarted"
		@page_class = "overview"

		@prevlink = ""
		nextPage = @config['Pages'][1]
		@nextlink = %Q{<a href="#{nextPage['file']}.html" class="nextlink">#{nextPage['title']} <b>&#9654;</b></a>}

		text = ERB.new(Utils.load_template(infile)).result(binding)
		text = text.render_liquid

		has_images = text.scan(/\[(.*?)\]:\s*(?!http)(.*?\.(jpg|png|gif|svg))\s*$/)
		if has_images.length > 0
			Utils.update_status("Adding sizes to #{has_images.length} images")
			has_images.each {|image_match|
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
		end

		@content = %x{echo #{Shellwords.escape(Utils.remove_todos(text))}|/usr/local/bin/multimarkdown}
		@prefix = './'

		File.open(@outfolder+'/index.html', "w+") do |outfile|
			outfile.puts(template.result(binding))
		end
		File.open(@help_outfolder+'/index.html', "w+") do |outfile|
			outfile.puts(help_template.result(binding))
		end
	end


	def generate_index(prefix)
		Utils.update_status("Building Sidebar")

		index_template = ERB.new <<-SECTIONTEMPLATE
			<ul class="uk-nav"><%= @lessons %></ul>
		SECTIONTEMPLATE




		@lessons = ""
		@config["Pages"].each do |page|
			@title = page["title"]
			@filename = page["file"]
			@page_class = @filename.downcase.gsub(/[-_]/,'')
			@lessons += ERB.new(%{<li><a class="<%= @page_class %>" href="<%= @filename %>.html"><%= @title %></a></h4></li>\n}).result(binding)
		end


		return index_template.result(binding)
	end

	def generate_page(page, prevPage, nextPage)
		Utils.update_status("Generating page: #{page['title']}")
		@subtitle = page['title']

		infile = "#{@basefolder}/content#{@settings[:debug]}/#{page['file']}.md"
		outfile = "#{@outfolder}/#{page['file']}.html"
		help_outfile = "#{@help_outfolder}/#{page['file']}.html"

		@prevlink = prevPage ? %Q{<a href="#{prevPage[:url]}.html" class="prevlink"><b>&#9664;</b> #{prevPage[:title]}</a>} : ""
		@nextlink = nextPage ? %Q{<a href="#{nextPage[:url]}.html" class="nextlink">#{nextPage[:title]} <b>&#9654;</b></a>} : ""
		@nextuplink = nextPage ? %Q{<h4 class="nextup uk-heading-medium">Next up: #{@nextlink}</h4>} : ""
		@page_class = page["file"].downcase.gsub(/[-_]/,'')
		@section_class = page["file"].downcase.gsub(/[-_]/,'')
		@title = page["title"]
		@title = @config['Title'] + " - Changelog"


		section_folder = '.'
		prefix = '../'

		text = ERB.new(Utils.load_template(infile)).result(binding)
		text = text.render_liquid

		has_images = text.scan(/\[(.*?)\]:\s*(?!http)(.*?\.(jpg|png|gif|svg))\s*$/)
		if has_images.length > 0
			Utils.update_status("Adding sizes to #{has_images.length} images")
			has_images.each {|image_match|
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
		end

		@content = %x{echo #{Shellwords.escape(Utils.remove_todos(text))}|/usr/local/bin/multimarkdown}
		@sections = @index

		output = ERB.new(Utils.load_template("#{@basefolder}/resources/template.html")).result(binding)
		help_output = ERB.new(Utils.load_template("#{@basefolder}/resources/template_internal.html")).result(binding)

		[[outfile,output],[help_outfile,help_output]].each {|out|
			FileUtils.mkdir_p(File.dirname(out[0])) unless File.exists?(File.dirname(out[0]))
			unless File.directory?(File.dirname(out[0]))
				Utils.update_status("ERROR: #{File.dirname(out[0])} exists and is not a folder", {:last => true})
				Process.exit 1
			else
				File.open(out[0], "w+") do |f|
					f.puts(out[1])
				end
			end
		}
	end

	def build_help

		@config["Pages"].each_with_index do |page, i|
			prevPage = nil
			nextPage = nil

			if i > 0
				previous = @config["Pages"][i - 1]
				prevPage = {
					:url => previous['file'],
					:title => previous['title']
				}
			end

			if i < @config["Pages"].length - 1
				nxt = @config["Pages"][i + 1]
				nextPage = {
					:url => nxt['file'],
					:title => nxt['title']
				}
			end

			generate_page(page, prevPage, nextPage)
		end

		[@outfolder, @help_outfolder].each {|odir|
			Utils.update_status("Copying images to #{odir}")
			FileUtils.copy_entry("#{@basefolder}/content#{@settings[:debug]}/images","#{odir}/images")
			# FileUtils.copy_entry("#{@basefolder}/images","#{odir}/images")
		}
	end

	def file_list
		list = {}
		@config["Pages"].each do |page|
				list[page['file']] = page['file']
		end
		list
	end

	def keyword_list
		list = {}
		@config["Sections"].each do |section|
			folder = section['folder']
			section['pages'].each do |page|
				if page['keywords'] != nil
					page['keywords'].each do |keyword|
						list[keyword] = "#{folder}/#{page['file']}.html"
					end
				end
			end
		end
		list
	end

	def wiki_link(input,page,index)
		return input if @keywords.empty?
		prefix = index ? '' : '../'
		keywords.each do |k,v|
			if v !~ /.*?\/#{page}.html$/
				input.gsub!(/ (#{k})\b/i," [\\1](#{v})")
			end
		end
		input
	end

	def resolve_internal_links(input,index)
		list = @filelist
		prefix = index ? '' : '../'
		input.gsub(/\[\[(.*?)\]\]/) {|match|
			file = match.gsub(/\[\[(.*?)\]\]/,"\\1")
			suffix = '.html'
			if file =~ /(.+?)#(.+)$/
				file = $1
				suffix = '.html#'+$2
			end
			list[file] + suffix unless list[file].nil?
		}
	end

	def copy_dependencies
		@config["Dependencies"].each do |dep|
			dep = File.join(@config["DependenciesBase"],dep)
			if dep =~ /\.s?css$/
				Utils.update_status("Converting/Minifying CSS: #{dep}")
				filename = dep.gsub(/\.s?css$/,'')
				minified_fn = filename + ".min.css"
				if dep =~ /\.scss$/
					%x{sass --scss #{dep} #{filename}.css}
				end
				%x{/usr/local/bin/yuicompressor -o "#{minified_fn}" "#{filename}.css"}
				dep = minified_fn
				Utils.update_status("Minified: #{minified_fn}",{:last => true})
			end
			Utils.update_status("Copying #{dep}")
			if File.directory?(dep)
				[@outfolder,@help_outfolder].each do |folder|
					Utils.update_status("Copying #{dep} to #{folder}")
					FileUtils.cp_r(dep, folder)
				end
			else
				[@outfolder,@help_outfolder].each do |folder|
					FileUtils.copy("#{@basefolder}/#{dep}",folder) if dep =~ /(css|jpg|png|gif|json)$/
				end
			end
		end
		js_file = concat_js
		Utils.update_status("Created #{js_file}",{:last => true})
		FileUtils.copy("#{js_file}",@outfolder)
		FileUtils.copy("#{js_file}",@help_outfolder)
	end

	def read_html(html_file)
		f = File.open(html_file)
		doc = Nokogiri::HTML(f)
		f.close
		return doc
	end

	def strip_html(input)
		CGI.unescapeHTML(input.
		  gsub(/<(script|style|pre|code|figure).*?>.*?<\/\1>/im, '').
		  gsub(/<!--.*?-->/m, '').
		  gsub(/<(img|hr|br).*?>/i, " ").
		  gsub(/<(dd|a|h\d|p|small|b|i|blockquote|li)( [^>]*?)?>(.*?)<\/\1>/i, " \\3 ").
		  gsub(/<\/?(dt|a|ul|ol)( [^>]+)?>/i, " ").
		  gsub(/<[^>]+?>/, '').
		  gsub(/\[\d+\]/, '').
		  gsub(/&#8217;/,"'").gsub(/&.*?;/,' ').gsub(/;/,' ').
		  gsub(/\u2028/,'').
		  gsub(/[^a-z0-9,"'?\.! \n]/i,'')
		).strip.gsub(/[\t\n\r]+/,' ').squeeze(" ")
	end

	def find_stems(content)
		keywords = []
		words = content.gsub(/[^a-z0-9 ]/i,' ').split(" ").map {|word|
			word.gsub(/^\W+|\W+$/,'').strip.downcase
		}
		words.delete_if { |word| word.length < 3 }.delete_if { |word| @settings[:skipwords].include? word.gsub(/[^a-z0-9 ]/i,'').downcase }
		count = {}
		words = words.map { |word| Text::PorterStemming.stem(word).downcase }.uniq.each {|word|
			if count.key? word
				count[word] += 1
			else
				count[word] = 1
			end
		}

		count.delete_if {|c,v| v < 3}

		return count.keys
	end

	def generate_full_index
		Utils.update_status("Generating full keyword index")
		version = @version
		contents = []
		keywords = []
		@config["Pages"].each do |page|
			keywords = []
			page_title = page["title"]
			filename = page["file"]+".html"
			doc = read_html(@outfolder+"/"+filename)
			keywords = find_stems(doc.css('#content').text)
			if page["keywords"]
				keywords.concat(page["keywords"])
			end
			contents << {
				'title' => page_title,
				'link' => filename,
				'keywords' => keywords
			}
			index_item = {
				'title' => page_title,
				'loc' => filename,
				'tags' => keywords.join(" "),
				'text' => strip_html(doc.css('#content').text).to_json,
				'children' => []
			}
			doc.css('#content h2,#content h3').each do |link|
				keywords = []
				title_link = filename + "#" + link['id']
				title = link.content
				keywords = find_stems(title)
				contents << {
					'title' => (page_title + ": " + title).strip,
					'link' =>  title_link,
					'keywords' => keywords
				}
				if link.name == 'h2'
					index_item['children'].push({
						'title' => title.strip,
						'loc' => title_link
					})
				end
			end
			if index_item['children'].size > 0
				sections = ""
				index_item['children'].each {|c|
					sections += " #{c['title']}"
				}
				index_item['text'] = sections + " " + index_item['text']
			end
			@searchindex.push(index_item)
		end

		contents = contents.sort { |a,b|
			a['title'] <=> b['title']
		}

		output = %Q{<h1>Index</h1>\n<div class="uk-margin"><form action="search.html" class="uk-search uk-search-default"><input class="uk-search-input" type="search" placeholder="Keyword Filter" name="filter" id="topicsearch"></form></div>\n<ul id="topiclist">\n}

		contents.each{|item|
			output += "<li class=\"#{item['keywords'].join(' ')}\"><a href=\"#{item['link']}\">#{item['title']}</a></li>\n"
		}

		output += "</ul>\n\n"

		@subtitle = @main_title

		# infile = "#{@basefolder}/#{section_folder}/#{page["file"]}.md"
		# outfile = "#{@outfolder}/contents.html"
		@section_folder = '.'
		@title = "Index"
		@content = output
		@sections = @index.gsub(/\.\.\//,'')
		@prefix = ''
		@page_class = "fullindex"
		@section_class = "fullindex"
		output = ERB.new(Utils.load_template("#{@basefolder}/resources/template.html")).result(binding)
		help_output = ERB.new(Utils.load_template("#{@basefolder}/resources/template_internal.html")).result(binding)

		File.open("#{@outfolder}/contents.html", "w+") do |out|
			out.puts(output)
		end
		File.open("#{@help_outfolder}/contents.html", "w+") do |out|
			out.puts(help_output)
		end
	end

	def concat_js
		Utils.update_status("Concatenating JS")
		Dir.chdir(@basefolder)
		filename = @config["Title"].downcase.gsub(/[^a-z]/,'');
		concat_fn = filename + ".concat.js"
		minified_fn = filename + ".min.js"
		concat = File.new(concat_fn, "w+")
		@config["Dependencies"].each do |file|
			if file =~ /\.js$/
				File.open(File.join(@config["DependenciesBase"],file)).each do |line|
					concat.puts(line.chomp)
				end
			end
		end
		concat.close
		output = `/usr/local/bin/yuicompressor --nomunge "#{concat_fn}"`
		jquery = IO.read('resources/jquery.min.js')
		File.open(minified_fn,'w+') do |f|
			f.puts jquery
			f.puts output
		end
		return minified_fn
	end
end
