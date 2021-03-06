module Mardoc
  class Base
    include Rack::Utils
    
    def initialize(app=nil, options={})
      @app = app
      @docs_path   = File.join(Mardoc.proj_dir, Mardoc.docs_folder)
      @layout_path = File.join(Mardoc.proj_dir, Mardoc.layout_file)
      @internal_views_path = File.expand_path('views', File.dirname(__FILE__))
      @doc_index ||= Mardoc::Index.build
    end
    
    def call(env)
      @env = env
      @request = Rack::Request.new(env)
      @response = Rack::Response.new
      respond!
    end
  
    private
  
    def respond!
      @response['Content-Type'] = 'text/html'
      @response.write render(@request.path)
      @response.close
      @response.finish
    rescue Mardoc::PageNotFoundError
      render_404
    rescue Exception => e
      render_500(e)
    end
  
    def render(path)
      return render_sitemap if @request.path == '/sitemap'
      return render_search if @request.path == '/search'
      
      file_path   = File.join(@docs_path, path.sub(/\/$/, '/index').sub(/(\.md)?$/, '.md'))
      
      raise Mardoc::LayoutNotFoundError, "Layout not found at #{@layout_path}" unless File.exist? @layout_path
      raise Mardoc::PageNotFoundError, "Page not found at #{path}" unless File.exist? file_path 
      
      render_layout do
        render_doc(file_path)
      end
    end
    
    def render_sitemap
      sitemap_template_path = File.join(@internal_views_path, 'sitemap.html.erb')
      
      render_layout do
        ERB.new(File.read(sitemap_template_path)).result(binding)
      end
    end
    
    def render_search
      search_template_path = File.join(@internal_views_path, 'search.html.erb')
      search(@request.params['query'])
      
      render_layout do
        ERB.new(File.read(search_template_path)).result(binding)
      end
    end
    
    def render_layout(&block)
      context = Mardoc::Context.new(:doc_index => @doc_index,
                                    :request => @request)
      ERB.new(File.read(@layout_path)).result(context.get_binding(&block))
    end
  
    def render_doc(file_path)
      markdown = RDiscount.new(File.read(file_path))
      markdown.to_html
    end
  
    def render_404
      @response.status = 404
      @response.write ERB.new(File.read(File.join(@internal_views_path, '404.html.erb'))).result(binding)
      @response.close
      @response.finish
    end
  
    def render_500(exception)
      @response.status = 500
      @response.write ERB.new(File.read(File.join(@internal_views_path, '500.html.erb'))).result(binding)
      @response.close
      @response.finish
    end
    
  end
end
