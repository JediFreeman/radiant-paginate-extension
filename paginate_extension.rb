class PaginateExtension < Radiant::Extension
  version "1.0"
  description "Pagination with will_paginate"
  url "http://blog.aissac.ro/radiant/paginate-extension/"
  
  def activate 
    Radiant::Config['pagination.url_route'] ||= 'page/'
    PaginateExtension.const_set('UrlCache', Radiant::Config['pagination.url_route'])

    Page.send(:include, PaginateTags)
    Page.send(:include, PaginatePageExtensions)
  end
  
  def deactivate
  end
end