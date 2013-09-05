require 'erb'

class SwaggerReader

  def analyze_file(file, comment_str)
    code = {:code => [], :line_number => [], :file =>[]}
    pattern = /\s*#{comment_str}(.*)/

    File.open(file,"r") do |f|
      line_number = 1
      while (line = f.gets)

        if line =~ pattern
          source = $1
          code[:code] << source
          code[:file] << file
          code[:line_number] << line_number
        end

        line_number = line_number + 1
      end
    end 

    return code

  end

  def analyze_all_files(base_path, file_extension, comment_str)

    code = {:code => [], :line_number => [], :file =>[]}

    files = Dir["#{base_path}/**/*.#{file_extension}"].sort

    files.each do |file| 
      fcode = analyze_file(file,comment_str)
      [:code, :line_number, :file].each do |lab|
        code[lab] = code[lab] + fcode[lab]
      end
    end 

    return code

  end

  def sort_for_vars_declaration(code)

    tmp_vars = {:code => [], :line_number => [], :file =>[]}
    tmp_not_vars = {:code => [], :line_number => [], :file =>[]}

    cont = 0
    code[:code].each do |code_line|
      if code_line =~ /^\s*@/
        tmp_vars[:code] << code_line#.gsub(/@(?=([^"]*"[^"]*")*[^"]*$)/," ")
        tmp_vars[:line_number] << code[:line_number][cont]
        tmp_vars[:file] << code[:file][cont]
      else
        tmp_not_vars[:code] << code_line#.gsub(/@(?=([^"]*"[^"]*")*[^"]*$)/," ")
        tmp_not_vars[:line_number] << code[:line_number][cont]
        tmp_not_vars[:file] << code[:file][cont]
      end
      cont=cont+1
    end

    res = {:code => tmp_vars[:code] + tmp_not_vars[:code], :line_number => tmp_vars[:line_number] + tmp_not_vars[:line_number], :file => tmp_vars[:file] + tmp_not_vars[:file]}

    return res
  end

 
  def process_code(code)

    @swagger_namespaces = nil

    code = sort_for_vars_declaration(code)

    code[:code].insert(0,"source2swagger = SwaggerHash.new")
    code[:code] << "@swagger_namespaces = {}"
    code[:code] << "source2swagger.namespaces.each {|k,v| @swagger_namespaces[k] = v.to_hash}"
    str = code[:code].join("\n")

    begin
      str = code[:code].map { |line| "<% #{line} %>" }.join("\n")

      File.open('source.rb', 'w') do |f|
        f.puts('require "swagger_hash"')
        f.puts(code[:code].join("\n"))
      end

      ERB.new(str).result(binding)

      res = @swagger_namespaces

    rescue Exception => exception
      error_line = exception.backtrace.first.scan(/\(erb\):(\d+)/).flatten.first.to_i
      context_size = 10
      start_line = [0, error_line - context_size].max
      end_line = error_line + context_size

      snippet = code[:code][start_line..end_line].enum_with_index.map do |e, number|
        number += start_line + 1
        marker = number == error_line ? '=>' : '  '
        
        "%s %4d)  %s" % [marker, number, e]
      end.join("\n")
      
      raise SwaggerReaderException, "Error evaluating: #{exception.message}\n\n#{snippet}\n"

      # raise e.to_yaml
      # puts e.backtrace.join("\n")
      # raise SwaggerReaderException, "Error on the evaluation of the code in docs: #{res}\n#{str}\n#{e.inspect}" unless res.class==Hash
    end

    res.each do |k, v|
      res[k] = v.to_hash
    end

    res  
  end

end

class SwaggerReaderException < Exception

end

