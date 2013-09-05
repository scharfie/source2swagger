class SwaggerHash < Hash
  
  # KEEP_METHODS = %w{default []= each merge! debugger puts __id__ __send__ instance_eval == equal? initialize delegate caller object_id raise class [] to_json inspect to_s new nil?}
  # ((private_instance_methods + instance_methods).map(&:to_sym) - KEEP_METHODS.map(&:to_sym)).each{|m| undef_method(m) }
  
  # def default(key)
  #   self[key] = SwaggerHash.new
  # end
    
  def initialize
    @namespaces = Hash.new
    ##super
  end

  def namespace(name)
    @namespaces[name] ||= SwaggerHash.new
  end

  def namespaces
    @namespaces
  end

  def method_missing(method, *args, &block)
    if method.to_s.match(/=$/)
      key = method.to_s.gsub("=","").to_sym 
      self[key] = args.first
    else
      if self[method].nil?
        if method != :add
          result = SwaggerHash.new
          block.call(result) if block
          self[method] = result
        else
          result = SwaggerHash.new
          result.set(args.last) if args.any?
          block.call(result) if block

          self[:_array] ||= Array.new 
          self[:_array] << result

          return result
        end
      end

      return self[method]
    end
  end
  
  def set(*args)
    merge!(*args)  
  end
  
  def to_hash
    h2 = Hash.new
    self.each do |k,v|
      if v.class != SwaggerHash && v.class != Hash
        h2[k] = v 
      else
        if not (v[:_array].nil?)
          v2 = []
          v[:_array].each do |item|
            v2 << item.to_hash
          end
          h2[k] = v2
        else
          h2[k] = v.to_hash
        end
      end
    end
    return h2
  end
 
end
