
class HelpPDFBuilder
	include Utils
	attr_accessor :config, :outfolder, :basefolder, :version
	def initialize

		@cat = []

		@settings = DEFAULT_SETTINGS.dup
		@internal = ''
		@libdir = File.dirname(__FILE__)
		@basefolder = File.expand_path(File.join(@libdir,'..'))
		@resourcefolder = File.join(@basefolder, 'resources')

		Dir.chdir(@basefolder)
		config_file = File.expand_path(@basefolder + "/config.yaml")

		@config = Utils.load_config(config_file)

		@main_title = @config["Title"]
		@main_logo = @config["Logo"]

		@version = @config['Version'].to_s

		@outfolder = File.expand_path(@basefolder+"/"+@config["Title"]+".pdf")

		@outpdf = File.join(@basefolder,'nvUltraHelp.pdf')

		@searchindex = []

		# Make storage directory if needed
		FileUtils.mkdir_p(@outfolder,:mode => 0755) unless File.exists? @outfolder

# 		titleblock =<<ENDTITLEBLOCK

# ![](images/logo_large.png)

# ENDTITLEBLOCK

# 		@cat.push(titleblock)

		build_help

		copy_dependencies

		run_pandoc
	end

	# I forced most of the headings in the document to be globally unique so
	# that when I linked between pages I could always include a hash target, and
	# when I generate the PDF I can just remove everything *but* the hash target
	# and the same intra-doc links will work in both web and PDF scenarios.
	def fix_local_links(input)
		input.gsub(/\]\((?!http).*?(#[^\)]+)\)/i, '](\1)')
	end

	def run_pandoc

		compiled = @cat.join("\n\n").symbolify_symbols

		compiled = fix_local_links(compiled)
		# Most fonts are missing the right triangle character,
		# but menlo has it, so we make sure it's always in a code span
		compiled.gsub!(/▸/,'`▸`')

		comp_target = File.join(@outfolder,'compiled.md')


		File.open(comp_target,'w') do |f|
			f.puts compiled
			Utils.update_status("Compiled Markdown to #{comp_target}")
		end

		Dir.chdir(@outfolder)

		# Pandoc, and even more so LaTeX, are black magic to me. I can make them
		# do wondrous things by poking at them with different size sticks, but
		# I have no consistency. Thus some things are passed as metadata, some as
		# variables, some imported into the head from external files, some passed
		# on the command line. This will improve with time.

		vars = [
							'geometry:margin=2cm',
							'fontsize=12pt',
							'title="nvUltra Documentation"',
							'author="Fletcher Penney and Brett Terpstra"',
							'colorlinks'
						]
		args = [
						'--top-level-division=section',
						'-f markdown_mmd',
						"--include-in-header \"#{File.join(@resourcefolder,'chapterbreak.tex')}\"",
						'--toc',
						'--toc-depth=2',
					  '--pdf-engine=xelatex',
					  '--highlight-style=zenburn',
					  "--template \"#{File.join(@resourcefolder,'pdf_template.template')}\"",
					  "--metadata=date:#{Time.now.strftime('%Y-%m-%d')}",
					  "--data-dir=resources"
					]

		Utils.update_status("Compiling PDF with Pandoc")
		%x{pandoc compiled.md #{args.join(" ")} -V #{vars.join(" -V ")} -o \"#{@outpdf}\"}
		Utils.update_status("Compiled PDF to #{@outpdf}",{:last => true})
		%x{open #{@outpdf}}
	end

	def generate_page(page)
		Utils.update_status("Generating page: #{page['title']}")
		@subtitle = page['title']

		infile = "#{@basefolder}/content#{@settings[:debug]}/#{page['file']}.md"

		@title = page["title"]

		section_folder = '.'
		prefix = '../'

		text = ERB.new(Utils.load_template(infile)).result(binding)
		text = text.render_liquid(pdf: true)

		# remove all @2x images for PDF generation
		text.gsub!(/@2x(\.(?:png|jpe?g|gif))/,'\1')

		@cat.push(Utils.remove_todos(text))
	end

	def build_help

		@config["Pages"].each_with_index do |page, i|
			generate_page(page) unless page['pdf_ignore']
		end

		Utils.update_status("Copying images to #{@outfolder}")
		FileUtils.copy_entry("#{@basefolder}/content#{@settings[:debug]}/images","#{@outfolder}/images")
	end

	def copy_dependencies
		@config["Dependencies"].each do |dep|
			src = File.join(@basefolder,@config["DependenciesBase"],dep)
			if File.directory?(src)
					FileUtils.cp_r(src, @outfolder)
			else
				FileUtils.copy(src, @outfolder) if dep =~ /(css|jpg|png|gif|json)$/
			end
		end
	end
end
