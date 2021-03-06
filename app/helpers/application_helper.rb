require 'open-uri'

module ApplicationHelper

  def attachment(object, caption = true, options={})
    return '' if object.nil?
    tag = case object['content_type']
    when /^image/
      image_tag(object['web_url'], options)
    when /^video/
      video_tag(object['web_url'], options.merge(controls: true))
    end
    if caption === true
      caption = content_tag(:figcaption, asset_caption(object))
      content_tag(:figure, tag + caption)
    else
      tag
    end
  end

  def asset_caption(asset)
    title = h asset['title']
    if asset['description'].present?
      title += "; " + asset['description']
    end
    byline = h(asset['attribution'])
    byline = "By #{h asset['creator']}" if byline.blank? && asset['creator'].present?
    byline_link = link_to byline, asset['source'] if asset['source'] && byline
    license = Odlifier.translate(asset['license'], nil)
    [title, byline_link, license].select{|x| !x.blank?}.join('. ').html_safe
  end

  def author(publication)
    if publication.author
      if publication.author['tag_ids'].include?("team") && publication.author['state'] == 'published'
        link_to team_article_path(publication.author["slug"]), :class => "author" do
          "#{publication.author["name"]} #{author_image(publication.author)}".html_safe
        end
      else
        content_tag :span, publication.author["name"], :class => "author"
      end
    end
  end

  def module_block(section, publication)
  	begin
  		render :partial => "module/#{section.gsub('-', '_')}", :locals => { :section => section, :publication => publication }
    rescue ActionView::MissingTemplate
  	  render :partial => 'module/block', :locals => { :section => section, :publication => publication }
  	end
  end

  def date_range(from_date, until_date)
    if from_date.to_date == until_date.to_date
     "#{from_date.strftime("%A %d %B %Y")}, #{from_date.strftime("%l:%M%P")} - #{until_date.strftime("%l:%M%P")}"
    else
     "#{from_date.strftime("%A %d %B %Y")} #{from_date.strftime("%l:%M%P")} - #{until_date.strftime("%A %d %B %Y")} #{until_date.strftime("%l:%M%P")}"
    end
  end

  def upcoming_event?
    @publication.end_date.to_datetime > DateTime.now
  end

  def country(iso_code)
    c = Country[iso_code]
    c ? c.name : nil
  end

  def node_title(publication)
    str = "ODI ".html_safe
    if publication.level == "comms"
      str += "Comms Link - "
    end
    str += publication.title || publication.name
    str += " (beta)" if publication.beta
    str
  end

  def node_subtitle(publication)
    if publication.level != "country"
      parts = [publication.host, publication.area, country(publication.region)]
      parts.reject!{|x| x.nil? || x.blank?}
      parts.join(', ')
    else
      nil
    end
  end

  def node_names(publication)
    publication.details.nodes.map{|x| node_title(x) }
  end

  def data_uri(uri)
    response = open(uri)
    "data:#{response.content_type};base64,#{Base64.encode64(response.read)}"
  end

  def page_title
    [
      content_for(:page_title),
      strip_tags(content_for(:title)).strip,
      'Open Data Institute'
    ].reject { |a| a.blank? }.join(' | ')
  end

  def canonical_url
    url_for :only_path => false
  end

  def article_meta page, type=:article
    meta :og => { :type => type.to_s }
    case page.format.to_sym
    when :article
      set_og_description page.details["description"]
      set_og_image page.details["content"]
    else
      set_og_description page.details["excerpt"]
    end
  end

  def speakers(publication)
    return nil unless publication.format == 'event'
    publication.artefact['related'].map! { |r| OpenStruct.new(r) }
    publication.artefact['related'].select do |r|
      r.format == 'person'
    end
  end

  def marshal_sessions(sessions)
    times = {}

    sessions.each do |s|
      details = s.details

      time = Time.parse(details['start_date']).strftime("%H:%M:%S")
      times[time] ||= []
      times[time] << {
        title: s.title,
        slug: s.slug,
        start_date: details['start_date'],
        end_date: details['end_date'],
        location: details['location'],
        module_image: details['module_image'].try(:[], 'web_url')
      }
    end

    times
  end

  def session_time(time)
    Time.parse(time).strftime('%l:%M %P')
  end

  def person_image(person)
    person.id.gsub('.json', '/image?version=square')
  end

  def author_image(author)
    image_tag "http://contentapi.theodi.org/#{author['slug']}/image?version=square", alt: author['name'], size: "50x50"
  end

  def summit_speakers(speakers)
    body = """
      <hr />
      <h2>Speakers</h2>
    """
    body << render(:partial => 'content/speakers', :locals => { :speakers => speakers })
  end

  def summit_description(publication, speakers)
    publication.description.gsub(/^.+\[speakers\].+$/, summit_speakers(speakers)).html_safe
  end

  def parse_to_local_time(string)
    tz = TZInfo::Timezone.get("Europe/London");
    tz.utc_to_local(DateTime.parse(@publication.start_date));
  end


  private

  def set_og_description content
    if content.present?
      meta :og => { :description => content }
    end
  end

  def set_og_image content
    doc = Nokogiri::HTML( content )
    images = doc.css('img').map{ |i| i['src'] } # Array of strings
    if images.length > 0
      meta :og => { :image => images[0] }
    end
  end

end
