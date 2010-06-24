# encoding: UTF-8

module PaginateTags
  include Radiant::Taggable
  include WillPaginate::ViewHelpers
  
  class RadiantLinkRenderer < WillPaginate::LinkRenderer
    include ActionView::Helpers::TagHelper

    def initialize(tag)
      @tag = tag
    end
    
    def page_link(page, text, attributes = {})
      attributes = tag_options(attributes)
      @paginate_url_route = @paginate_url_route.blank? ? PaginateExtension::UrlCache : @paginate_url_route
      pagination_url = "#{@tag.locals.page.url}#{@paginate_url_route}#{page}"
      if ( !@options[:first_page_url].nil? and !@options[:first_page_url].empty? ) and page == 1
        pagination_url = "#{@options[:first_page_url]}"
      end 
      %Q{<a href="#{pagination_url}"#{attributes}>#{text}</a>}
    end
    
    def gap_marker
      '<span class="gap">&#8230;</span>'
    end

    def page_span(page, text, attributes = {})
      attributes = tag_options(attributes)
      "<span#{attributes}>#{text}</span>"
    end
  end
  
  desc %Q{
    Wrapper for pagination content. @<r:paginate:each>@ and @<r:paginate:pages>@ must be nested inside.
    
    *Usage:*
    
    <pre><code><r:paginate [per_page="10"] [order="asc|desc"] [by="attribute"] [excludes="part-name[,page-part]"]>
      ...
      <r:each>...</r:each>
      ...
      <r:pages />
    </r:paginate></code></pre>
  }
  tag 'paginate' do |tag|
    tag.locals.previous_headers = {}
    
    parents = tag.locals.parent_ids || paginate_find_parent_pages(tag)
    options = paginate_find_options(tag)
    excludes = tag.attr['excludes'].blank? ? Array.new : tag.attr['excludes'].split(',').to_a

    excludes = PagePart.find(
      :all,
      :joins => :page,
      :conditions => ["name in (?) AND pages.parent_id in (?)", excludes, parents],
    ).collect { |part| part.page_id }

    paginated_children = Page.paginate(options.merge(
      :conditions => ["pages.parent_id in (?) AND pages.id not in (?)
                       AND virtual = ? and status_id = ? ", parents, excludes, false, 100])
    )

    tag.locals.paginated_children = paginated_children
    
    tag.expand
  end
  
  desc %Q{
    Renders nested content for each child of current page. Must be placed inside @<r:paginate>@
    
    *Usage:*
    
    <pre><code><r:paginate [per_page="10"] [order="asc|desc"] [by="attribute"]>
      <r:each>
        <r:link />
      </r:each>
    </r:paginate>
    </code></pre>
  }
  tag 'paginate:each' do |tag|
    result = []
    
    tag.locals.paginated_children.each_with_index do |item, index|
      tag.locals.child = item
      tag.locals.page = item
      tag.locals.index = index
      result << tag.expand
    end
    result
  end
  
  desc %Q{
    Expands when this is the first child in paginate:each
  }
  tag 'paginate:each:if_first' do |tag|
    tag.expand if tag.locals.index == 0
  end
  
  desc %Q{
    Expands unless this is the first child in paginate:each
  }
  tag 'paginate:each:unless_first' do |tag|
    tag.expand unless tag.locals.index == 0
  end
  
  desc %Q{
    Renders pagination links with will_paginate.
    The following optional attributes may be controlled:
    
    * id - the id to apply to the containing @<div>@
    * class - the class to apply to the containing @<div>@
    * prev_label - default: "« Previous"
    * next_label - default: "Next »"
    * inner_window - how many links are shown around the current page (default: 4)
    * outer_window - how many links are around the first and the last page (default: 1)
    * separator - string separator for page HTML elements (default: single space)
    * page_links - when false, only previous/next links are rendered (default: true)
    * show_endcap_link - when false, does not show next link on last page or prev link on first page (default: true)
    * first_page_url - when set, overrides the url of the pagination control for the first page link (for example, to send to homepage on page 1) 
    
    *Usage:*
    
    <pre><code><r:paginate>
      <r:pages [id=""] [class="pagination"] 
      [prev_label="&laquo; Previous"] 
      [next_label="Next &raquo;"] 
      [inner_window="4"] [outer_window="1"]
      [separator=" "] [page_links="true"]
      [show_endcap_link="true"] [first_page_url=""]
      />
    </r:paginate>
    </code></pre>
  }
  tag 'paginate:pages' do |tag|
    renderer = RadiantLinkRenderer.new(tag)
    
    options = {}
    
    [:id, :class, :prev_label, :next_label, :inner_window, :outer_window, :separator, :first_page_url].each do |a|
      options[a] = tag.attr[a.to_s] unless tag.attr[a.to_s].blank?
    end
    options[:page_links] = false if 'false' == tag.attr['page_links']
    options[:container]  = false #if 'false' == tag.attr['container']
    
    show_endcap_link = true
    if (!tag.attr["show_endcap_link"].nil? and !tag.attr["show_endcap_link"].empty?)
      show_endcap_link = false if 'false' == tag.attr['show_endcap_link']
    end
    if !show_endcap_link
      options[:next_label] = '' if tag.locals.paginated_children.next_page.nil?
      options[:prev_label] = '' if tag.locals.paginated_children.previous_page.nil?
    end
    
    will_paginate tag.locals.paginated_children, options.merge(:renderer => renderer)
  end
  
  private
    def paginate_find_parent_pages(tag)
      attr = tag.attr.symbolize_keys
      
      level = (attr[:level] || '1').to_i
      page = attr[:url] && Page.find_by_url(attr[:url]) || tag.locals.page
      
      if level == 2
        page.children.map(&:id)
      else
        [page.id]
      end
    end
  
    def paginate_find_options(tag)
      attr = tag.attr.symbolize_keys
      
      options = {}
      
      options[:page] = tag.attr['page'] || request.path[/^#{Regexp.quote(tag.locals.page.url)}#{Regexp.quote(PaginateExtension::UrlCache)}(\d+)\/?$/, 1]

      options[:per_page] = tag.attr['per_page'] || 10
      
      by = (attr[:by] || 'published_at').strip
      order = (attr[:order] || 'asc').strip
      order_string = ''
      if self.attributes.keys.include?(by)
        order_string << by
      else
        raise TagError.new("`by' attribute of `each' tag must be set to a valid field name")
      end
      if order =~ /^(asc|desc)$/i
        order_string << " #{$1.upcase}"
      else
        raise TagError.new(%{`order' attribute of `each' tag must be set to either "asc" or "desc"})
      end
      options[:order] = order_string
      
      options
    end
end
