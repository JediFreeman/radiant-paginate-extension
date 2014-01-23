module PaginatePageExtensions
  def self.included(base)
    base.class_eval do
      alias_method_chain :find_by_url, :paginate
      alias_method_chain :find_by_path, :paginate
    end
  end
  
  def find_by_url_with_paginate(url, live = true, clean = true)
    @paginate_url_route = @paginate_url_route.blank? ? PaginateExtension::UrlCache : @paginate_url_route
    url = clean_url(url) if clean
    #target = nil
    if url =~ %r{^#{ self.url }#{@paginate_url_route}\d+\/$}
      #target = self
      return self
    else
      #target = find_by_url_without_paginate(url, live, clean)
      return find_by_url_without_paginate(url, live, clean)
    end
    #return target
  end
  
  def find_by_path_with_paginate(path, live = true, clean = true)
    @paginate_url_route = @paginate_url_route.blank? ? PaginateExtension::UrlCache : @paginate_url_route
    path = clean_path(path) if clean
    #target = nil
    if path =~ %r{^#{ self.path }#{@paginate_url_route}\d+\/$}
      #target = self
      return self
    elsif path =~ %r{^#{ self.path }(\d{4})(?:\/(\d{2})?)(?:\/(\d{2})?)#{@paginate_url_route}\d+\/$}
      # archive!
      #target = self
      return self
    else
      #target = find_by_path_without_paginate(path, live, clean)
      return find_by_path_without_paginate(path, live, clean)
    end
    #return target
  end
end