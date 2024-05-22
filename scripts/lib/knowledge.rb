#!/usr/bin/env ruby

class KnowlegeBase
  include Utils
  KB_APIKEY = "adc3d3d5cbbb264835c2a288df46f546c0778310"
  KB_SITE   = "marked"
  KB_EXPORTDIR = "/Users/ttscoff/Desktop/Code/marked/HelpDocs/content"

  def get_kb_response(url)
    cmd = %Q{curl -sS -H "Accept: application/vnd.tender-v1+json" -H "X-Tender-Auth: #{KB_APIKEY}" #{url}}
    res = %x{#{cmd}}
    JSON.parse(res)
  end

  def retrieve_kb
    kbsections = []
    # main_index = File.join(KB_EXPORTDIR,"Knowledgebase.md")

    get_kb_response("http://api.tenderapp.com/#{KB_SITE}/sections")['sections'].each do |section|
      body = ''
      toc = ''
      unless section['faqs_count'] > 0
        next
      end
      faqs = get_kb_response("#{section['href']}/faqs")['faqs']
      sec_title = section['title']
      sec_folder = sec_title.sanitized
      sec_index = File.join(KB_EXPORTDIR, "#{sec_folder}.md")
      # %w(beta draft).each {|sub| # create beta and draft folders for section
      #   FileUtils.mkdir_p(File.join(KB_EXPORTDIR, sub))
      # }
      # sec_toc = "# #{sec_title}\n\n"
      # toc << "\n\n## [#{sec_title}](kb_#{sec_folder}_index.hml)\n\n"
      # kbpages = []
      faqs.each do |faq|
        title = faq['title']
        toc << "* [#{title}](##{title.sanitized.downcase})\n"
        # filename = sec_folder + '_' + title.sanitized + ".md"
        # file = File.join(KB_EXPORTDIR, filename)
        # if faq['beta']
        #   file = File.join(KB_EXPORTDIR, 'beta', filename)
        # elsif Time.parse(faq['published_at']) > Time.now
        #   file = File.join(KB_EXPORTDIR, 'draft', filename)
        # else
        #   toc << "* [#{title}](##{title.sanitize})\n"
        #   toc << "* [#{title}](#{filename.sub(/md$/,'html')})\n"
        #   kbpages << {
        #     'title' => title,
        #     'file' => title.sanitized # File.join('knowledgebase', sec_folder, title.sanitized)
        #   }
        # end
        # classes << 'beta' if faq['beta']
        # classes << 'important' if faq['important']
        # classes << 'draft' if Time.parse(faq['published_at']) > Time.now
        body << "## #{title} [#{title.sanitized.downcase}]\n\n"
        body << faq['body'].
          gsub(/\/assets/, "http://#{KB_SITE}.tenderapp.com/help/assets").
          # gsub(/\/help\/assets/, "http://#{KB_SITE}.tenderapp.com/help/assets").
          gsub(/^#/,'##')
        body << "\n\n[Table of contents](#toc)\n\n"
        # File.open(file, "w") { |f| f.write body }

        Utils.update_status ("retrieved #{sec_title}/#{title}")
      end
      kbsections << {
        'title' => sec_title,
        'file' => sec_folder
      }
      output = "# <%= @title %> [toc]\n\n" + body #  + toc + "\n\n" + body
      File.open(sec_index, "w") { |f| f.write output }
      Utils.update_status("@@@ index for #{sec_title} written to #{sec_index}",{:last=>true})
    end
    # File.open(main_index, "w") { |f| f.write toc }
    # $stderr.puts("@@@ knowledge base index written to #{main_index}")
    return kbsections
  end
end
