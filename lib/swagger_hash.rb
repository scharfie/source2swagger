class SwaggerHash < Hash
  
  # KEEP_METHODS = %w{default []= each merge! debugger puts __id__ __send__ instance_eval == equal? initialize delegate caller object_id raise class [] to_json inspect to_s new nil?}
  # ((private_instance_methods + instance_methods).map(&:to_sym) - KEEP_METHODS.map(&:to_sym)).each{|m| undef_method(m) }
  
  # def default(key)
  #   self[key] = SwaggerHash.new
  # end
    
  def initialize(properties={})
    @namespaces = Hash.new

    properties.each do |key, value|
      send "#{key}=", value
    end

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

  # model extensions
  def model(name, &block)
    result = models[name] = SwaggerHash::Model.new(
      :id => name
    )

    block.call(result) if block
    result
  end

  # might need a better home for this eventually
  def parameter(name, type, options={})
    defaultValue = options.delete(:default)
    allowableValues = options.delete(:allowed) || allowable_values_for_type(type)

    case allowableValues
    when Range
      min, max = allowableValues.min, allowableValues.max
      allowableValues = build_range(min, max)
    when Array
      allowableValues = build_list(allowableValues)
    end

    defaults = {
      :paramType => "form",
      :required => true,
      :defaultValue => defaultValue, 
      :allowableValues => allowableValues,
      :name => name,
      :dataType => type
    }

    options = defaults.merge(options)
    parameters.add options
  end

  # convenience method for adding some pagination fields
  def pagination!
    parameter :page, :integer, :required => false, :default => 1, :paramType => "query"
    parameter :per_page, :integer, :required => false, :default => 30, :paramType => "query", 
      :allowed => 1..1000
  end

  def allowable_values_for_type(type)
    case type.to_sym
    when :integer
      build_range(0.0, "Infinity")
    else
      nil
    end
  end

  def build_range(min, max)
    { 
      :valueType => "RANGE",
      :min => min,
      :max => max
    }
  end

  def build_list(array)
    {
      :valueType => "LIST",
      :values => array
    }
  end
end

class SwaggerHash::Model < SwaggerHash
  def property(name, type, options={})
    result = properties[name] = SwaggerHash::ModelProperty.new(
      { :type => type }.merge(options)
    )

    result
  end

  def string(name, options={})
    property(name, :string, options)
  end

  def integer(name, options={})
    property(name, :integer, options)
  end

  def boolean(name, options={})
    property(name, :boolean, options)
  end

  def date(name, options={})
    property(name, :date, options)
  end

  def datetime(name, options={})
    property(name, :datetime, options)
  end

  def array(name, type, options={})
    properties[name] = SwaggerHash::ModelProperty.new(
      :type => "array",
      :items =>  {
        "$ref" => type
      }
    )
  end
end

class SwaggerHash::ModelProperty < SwaggerHash

end
