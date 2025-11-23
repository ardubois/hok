defmodule Hok.CudaBackend do
  ########
  #Generating a new module in pure Elixir to substitute the Hok module in the Elixir program
  ################
  def gen_new_module(header,body) do
    new_body =  case body do
          {:__block__, [], definitions} ->  gen_new_definitions(definitions)
          _   -> gen_new_definitions([body])
    end

    new_module = quote do
      defmodule (unquote(header)) do
       unquote(new_body)
       end
    end

    new_module

  end

  defp gen_new_definitions([]), do: []
  defp gen_new_definitions([{:deft,_,_para}|t]) do

      gen_new_definitions(t)
  end
  defp gen_new_definitions([{:include,_,_para}|t]) do

    gen_new_definitions(t)
end
  defp gen_new_definitions([{:defh , _, [header, _code] }| t]) do
  {fname, comp_info, para} = header

    para = para
    |> Enum.map(fn {p, b, c}-> {String.to_atom("_" <> to_string(p)),b,c} end)

    new_code = quote do: (def unquote({fname, comp_info, para}), do:  raise "A hok function can only be called by kernels!")

    [new_code | gen_new_definitions(t)]
  end
  defp gen_new_definitions([{:defk , _, [header, _code] }| t]) do
    {fname, comp_info, para} = header

    para = para
    |> Enum.map(fn {p, b, c}-> {String.to_atom("_" <> to_string(p)),b,c} end)
    new_code = quote do: (def unquote({fname, comp_info, para}), do: raise "A kernel can only be executed with spawn!")
    [new_code | gen_new_definitions(t)]
  end
  defp gen_new_definitions([h | t]) do
      [h | gen_new_definitions(t)]
  end

  ############ Compile Hok Module
  def compile_module(module_name,body) do

    # initiate server that collects types and asts
    pid = spawn_link(fn -> types_ast_server(%{},%{}) end)
    Process.register(pid, :types_ast_server)

    code = case body do
        {:__block__, [], definitions} ->  compile_definitions(module_name,definitions)
        _   -> compile_definitions(module_name,[body])
    end

    send(pid,{:get_map,self()})

    {map_types,map_asts} = receive do
      {:map,{map_types,map_asts}} -> {map_types,map_asts}
      _     -> raise "unknown message for function type server."
    end

    File.write!("c_src/Elixir.#{module_name}.types", :erlang.term_to_binary(map_types))
    File.write!("c_src/Elixir.#{module_name}.asts", :erlang.term_to_binary(map_asts))
    Process.unregister(:types_ast_server)
    send(pid,{:kill})
    code
  end

###########################
######  This server constructs two maps: 1. function names ->  types
#                                        2. function names -> ASTs
######            Types are used to type check at runtime a kernel call
######            ASTs are used to recompile a kernel at runtime substituting the names of the formal parameters of a function for
######         the actual parameters
############################
  def types_ast_server(types_map,ast_map) do
     receive do
      {:add_ast,fun, ast} ->
        types_ast_server(types_map,Map.put(ast_map,fun,ast))
       {:add_type,fun, type} ->
        types_ast_server(Map.put(types_map,fun,type),ast_map)
       {:get_map,pid} ->  send(pid, {:map,{types_map,ast_map}})
        types_ast_server(types_map,ast_map)
       {:kill} ->
             :ok
       end
  end

  #############################################
  ##### Compiling the definitions in a Hok module
  #####################
  defp compile_definitions(_module_name, []), do: ""
  defp compile_definitions(module_name,[h|t]) do
    if is_type_definition(h) do
        if t == [] do
          {:deft,_,[{fname,_,_}]} = h
          raise "Type definition for #{fname} is not followed by function definition!"
        end
        [definition | rest ] = t
        case definition do
           {:defh , _, _ } ->   code = compile_function(module_name,definition,h,module_name)
                                rest_code = compile_definitions(module_name,rest)
                                code <> rest_code
           {:defk, _, _ } ->   code = compile_kernel(module_name,definition,h,module_name)
                              rest_code = compile_definitions(module_name,rest)
                              code <> rest_code
           _              -> raise "Type definition must be followed by gpu function or kernel definition #{definition}"
        end
    else
        case h do
          {:defk, _, _ } ->   code = compile_kernel(module_name,h, :none,module_name)
                            rest_code = compile_definitions(module_name,t)
                            code <> rest_code
          {:defh , _, _ } -> code = compile_function(module_name,h, :none,module_name)
                            rest_code = compile_definitions(module_name,t)
                            code <> rest_code
          {:include, _, [{_,_,[name]}]} -> #IO.inspect(name)
                                            code = File.read!("c_src/Elixir.#{name}.cu")
                                              |>  String.split("\n")
                                              |>  Enum.drop(1)
                                              |> Enum.join("\n")
                                            rest_code = compile_definitions(module_name,t)
                                            code <> rest_code
          _               -> compile_definitions(module_name,t)


        end
    end
  end
  defp is_type_definition({:deft,_,_}), do: true
  defp is_type_definition(_v), do: false

  ###########################
  ############ Compile a kernel
  ###################################

  def compile_kernel(_module_name,{:defk,_,[header,[body]]}, type_def,module) do
    {fname, iinfo, para} = header
    {delta,is_typed}  = if(is_tuple(type_def)) do
        types = get_type_fun(type_def)
        delta= para
          |> Enum.map(fn({p, _, _}) -> p end)
          |> Enum.zip(types)
          |> Map.new()
      {delta,true}
    else
      delta=para
        |> Enum.map(fn({p, _, _}) -> p end)
        |> Map.new(fn x -> {x,:none} end)
    {delta,false}
    end

    #IO.inspect delta
    #raise "hell"

    inf_types = Hok.TypeInference.type_check(delta,body)

    #IO.inspect inf_types
   # raise "hell"

    param_list = para
       |> Enum.map(fn {p, _, _}-> gen_para(p,Map.get(inf_types,p)) end)
       |> Enum.join(", ")

    types_para = para
       |>  Enum.map(fn {p, _, _}-> Map.get(inf_types,p) end)




    #inf_types = if is_typed do %{} else inf_types end
    #IO.inspect inf_types
    #raise "hell"

    ##############
    #fname = "#{module_name}_#{fname}"

    save_type_info(fname,:unit,types_para)

    save_ast_info(fname,{:defk,iinfo,[header,[body]]},is_typed, inf_types)

    #IO.inspect inf_types
    #raise "hell"

    cuda_body = Hok.CudaBackend.gen_cuda(body,inf_types,is_typed,module)
    k = Hok.CudaBackend.gen_kernel(fname,param_list,cuda_body)
    accessfunc = Hok.CudaBackend.gen_kernel_call(fname,length(para),Enum.reverse(types_para))
    "\n" <> k <> "\n\n" <> accessfunc
  end

  def save_type_info(name,return, types) do


    send(:types_ast_server,{:add_type,name,{return,types}})

  end
  def save_ast_info(name,ast,typed?,delta) do


    send(:types_ast_server,{:add_ast,name,{ast,typed?,delta}})

  end

  ##################### Compiling Lambdas ########################

  def gen_lambda(module,lambda) do
    name = gen_lambda_name()
    {code,type} = compile_lambda(lambda,[], name,module);
    file = File.open!("c_src/#{module}.cu", [:append])
    IO.write(file, "//#############################\n\n" <> code)
    File.close(file)
    {result, errcode} = System.cmd("nvcc",
        [ "--shared",
          "--compiler-options",
          "'-fPIC'",
          "-o",
          "priv/#{module}.so",
          "c_src/#{module}.cu"
    ], stderr_to_stdout: true)


    if ((errcode == 1) || (errcode ==2)) do raise "Error when compiling .cu file generated by Hok:\n#{result}" end

    {"anonymous_#{name}",type}
  end


  def gen_lambda_name() do
    for _ <- 1..10, into: "", do: <<Enum.random('0123456789abcdefghijklmno')>>
  end
  def compile_lambda({:fn, _, [{:->, _ , [para,body]}] }, type, name,module) do
#    IO.puts "Compile lambda!!!!!!!!!!!!!!!!!!!!!!!!!!!!11"
    fname = "anonymous_#{name}"

    {delta,is_typed,fun_type}  = if(!(type == [])) do
        [fun_type|_] = Enum.reverse(type)
        delta= para
          |> Enum.map(fn({p, _, _}) -> p end)
          |> Enum.zip(type)
          |> Map.new()
        {delta,true,fun_type}
  else
        delta=para
             |> Enum.map(fn({p, _, _}) -> p end)
             |> Map.new(fn x -> {x,:none} end)
            {delta,false,:none}

  end

  delta = Map.put(delta,:return,fun_type)

 # IO.inspect delta
 # raise "hell"

    inf_types = Hok.TypeInference.type_check(delta,body)
   # IO.puts "Finished infer types"

    fun_type = if is_typed do fun_type else Map.get(inf_types,:return) end

    param_list = para
      |> Enum.map(fn {p, _, _}-> gen_para(p,Map.get(inf_types,p)) end)
      |> Enum.join(", ")

    types_para = para
      |>  Enum.map(fn {p, _, _}-> Map.get(inf_types,p) end)


    #save_type_info(fname, Map.get(inf_types, :return),types_para)

    cuda_body = Hok.CudaBackend.gen_cuda(body,inf_types,is_typed,module)
    k =        Hok.CudaBackend.gen_function(fname,param_list,cuda_body,fun_type)
    ptr =      Hok.CudaBackend.gen_function_ptr(fname)
    get_ptr = Hok.CudaBackend.gen_get_function_ptr(fname)
    {"\n" <> k <> "\n\n" <> ptr <> "\n\n" <> get_ptr <> "\n\n", { Map.get(inf_types, :return), types_para}}
  end
  def compile_lambda(_other, _t, _n) do
    "Cannot compile the anonymous function."
  end

  #################### Compile a function

  def compile_function(_module_name,{:defh,_,[header,[body]]}, type_def,module) do
    {fname, _, para} = header
   # IO.inspect body
    #raise "hell"
    {delta,is_typed,fun_type}  = if(is_tuple(type_def)) do
        types = get_type_fun(type_def)
        [fun_type|_] = Enum.reverse(types)
        delta= para
          |> Enum.map(fn({p, _, _}) -> p end)
          |> Enum.zip(types)
          |> Map.new()
      {delta,true,fun_type}
    else
      delta=para
        |> Enum.map(fn({p, _, _}) -> p end)
        |> Map.new(fn x -> {x,:none} end)
    {delta,false,:none}
    end

    delta = Map.put(delta,:return,fun_type)

    inf_types = Hok.TypeInference.type_check(delta,body)

    fun_type = if is_typed do fun_type else Map.get(inf_types,:return) end

    param_list = para
      |> Enum.map(fn {p, _, _}-> gen_para(p,Map.get(inf_types,p)) end)
      |> Enum.join(", ")

    types_para = para
      |>  Enum.map(fn {p, _, _}-> Map.get(inf_types,p) end)

##################3
    #fname = "#{module_name}_#{fname}"
    save_type_info(fname, Map.get(inf_types, :return),types_para)

    cuda_body = Hok.CudaBackend.gen_cuda(body,inf_types,is_typed,module)
    k =        Hok.CudaBackend.gen_function(fname,param_list,cuda_body,fun_type)
    ptr =      Hok.CudaBackend.gen_function_ptr(fname)
    get_ptr = Hok.CudaBackend.gen_get_function_ptr(fname)


    "\n" <> k <> "\n\n" <> ptr <> "\n\n" <> get_ptr <> "\n\n"
end
defp get_type_fun({:deft , _ , [{_name,_, [type]}]}) do
      type_to_list(type)
end
defp type_to_list({:integer,_,_}), do: [:int]
defp type_to_list({:unit,_,_}), do: [:unit]
defp type_to_list({:float,_,_}), do: [:float]
defp type_to_list({:gmatrex,_,_}), do: [:matrex]
defp type_to_list([type]) do
  ltype = type_to_list(type)
  [ {List.last(ltype), List.delete_at(ltype, length(ltype)-1)}]
end
defp type_to_list({:~>,_, [a1,a2]}), do: type_to_list(a1) ++ type_to_list(a2)
defp type_to_list({x,_,_}), do: raise "Unknown type constructor #{x}"
def gen_para(p,:matrex) do
  "float *#{p}"
end
def gen_para(p,:float) do
  "float #{p}"
end
def gen_para(p,:int) do
  "int #{p}"
end
def gen_para(p, {ret,type}) do
  #size = length(list)

  #{ret,type}=List.pop_at(list,size-1)
  #IO.inspect list
  #IO.inspect ret
  #IO.inspect type
  #raise "hell"
  r="#{ret} (*#{p})(#{to_arg_list(type)})"
  r

end
defp to_arg_list([:matrex]) do
  "float*"
end
defp to_arg_list([:matrex|t]) do
  "float*," <> to_arg_list(t)
end
defp to_arg_list([t]) do
  "#{t}"
end
defp to_arg_list([v|t]) do
  "#{v}," <> to_arg_list(t)
end

def gen_function_ptr(fname) do
    "__device__ void* #{fname}_ptr = (void*) #{fname};"
end
def gen_get_function_ptr(fname) do
    ("extern \"C\" void* get_#{fname}_ptr()\n" <>
    "{\n" <>
      "\tvoid* host_function_ptr;\n" <>
      "\tcudaMemcpyFromSymbol(&host_function_ptr, #{fname}_ptr, sizeof(void*));\n" <>
      "\treturn host_function_ptr;\n" <>
    "}\n")
end
def gen_kernel(name,para,body) do
    "__global__\nvoid #{name}(#{para})\n{\n#{body}\n}"
end
def gen_function(name,para,body,type) do
    "__device__\n#{type} #{name}(#{para})\n{\n#{body}\n}"
end

########################## ADDING RETURN statement to the ast WHEN FUNCTION RETURNS AN EXPRESSION

defp add_return(body) do
  send(:types_server,{:check_return, self()})
  resp = receive do
             msg  -> msg
  end
  if resp == nil do
    body
  else
    case body do
      {:__block__, pos, code} ->
              {:__block__, pos, check_return(code)}
      {:do, {:__block__,pos, code}} ->
              {:do, {:__block__,pos, check_return(code)}}
      {:do, exp} ->
          case exp do
            {:return,_,_} -> {:do, exp}
            _ ->  if is_exp?(exp) do
                    {:do, {:return,[],[exp]}}
                  else
                    {:do, exp}
                  end
          end
      {_,_,_} ->  if (is_exp?(body)) do
                    {:return,[],[body]}
                  else
                    body
                  end

    end
  end
end
defp check_return([com]) do
  case com do
        {:return,_,_} -> [com]
        {:if, info, [ exp,[do: block]]} -> {:if, info, [ exp,[do: check_return block]]}
        {:if, info, [ exp,[do: block, else: belse ]]} -> {:if, info, [ exp,[do: check_return(block), else: check_return(belse) ]]}
            _ -> if is_exp?(com) do
                    [{:return,[],[com]}]
                else
                  [com]
                end
  end
end
defp check_return([h|t]) do
  [h|check_return t]
end
defp is_exp?(exp) do
  case exp do
    {{:., _info, [Access, :get]}, _, [_arg1,_arg2]} -> true
    {{:., _, [{_struct, _, nil}, _field]},_,[]} -> true
    {{:., _, [{:__aliases__, _, [_struct]}, _field]}, _, []} -> true
    {op, _info, _args} when op in [:+, :-, :/, :*] -> true
    {op, _info, [_arg1,_arg2]} when op in [ :<=, :<, :>, :>=, :!=,:==] -> true
    {:!, _info, [_arg]} -> true
    {op, _inf, _args} when op in [ :&&, :||] -> true
    {var, _info, nil} when is_atom(var) -> true
    #{fun, _, args} when is_list(args)-> true
    #{_fun, _, _noargs} ->
    float when  is_float(float) -> true
    int   when  is_integer(int) -> true
    string when is_binary(string)  -> true
    _                              -> false

 end
end

#############################


def gen_cuda(body,types,is_typed,module) do
  # IO.puts "##########################gen cuda"
  # IO.inspect types
 #  IO.puts "############end gen cuda"
   # raise "hell"
    pid = spawn_link(fn -> types_server([],types,is_typed,module) end)
    Process.register(pid, :types_server)
    code = gen_body(body)
    send(pid,{:kill})
    Process.unregister(:types_server)
    code
  end
  def gen_body(body) do
    #IO.inspect body
    body = add_return(body)
    #IO.inspect(body)
    #raise "hell"
    case body do
      {:__block__, _, _code} ->
        gen_block body
      {:do, {:__block__,pos, code}} ->
        gen_block {:__block__, pos,code}
      {:do, exp} ->
        gen_command exp
      {_,_,_} ->
        gen_command body
    end

  end
  defp gen_block({:__block__, _, code}) do
    code
        |>Enum.map(&gen_command/1)
        |>Enum.join("\n")
  end
  defp gen_header_for(header) do
    case header do
      {:in, _,[{var,_,nil},{:range,_,[n]}]} ->
            "for( int #{var} = 0; #{var}<#{gen_exp n}; #{var}++)"
      {:in, _,[{var,_,nil},{:range,_,[argr1,argr2]}]} ->
            "for( int #{var} = #{gen_exp argr1}; #{var}<#{gen_exp argr2}; #{var}++)"
      {:in, _,[{var,_,nil},{:range,_,[argr1,argr2,step]}]} ->
            "for( int #{var} = #{gen_exp argr1}; #{var}<#{gen_exp argr2}; #{var}+=#{gen_exp step})"
    end
  end
  defp gen_command(code) do
  #  if check_atrib_last code do
   #    gen_atrib_last code
   # else
      case code do
        {:for,_,[param,[body]]} ->
          header = gen_header_for(param)
          body = gen_body(body)
          header <> "{\n" <> body <> "\n}\n"
        {:=, _, [arg, exp]} ->
          a = gen_exp arg
          e = gen_exp exp
          case arg do
            {{:., _, [Access, :get]}, _, [_,_]} ->
              "\t#{a} = #{e}\;"
            _ ->
              send(:types_server,{:check_var, a, self()})
              receive do
                {:is_typed} ->
                  "\t#{a} = #{e}\;"
                {:type,type}->
                   "\t#{type} #{a} = #{e}\;"
                {:alredy_declared} ->
                   "\t#{a} = #{e}\;"
              end
          end


        {:if, _, if_com} ->
            genIf(if_com)
        {:do_while, _, [[doblock]]} ->
            "do{\n" <> gen_body(doblock)
        {:do_while_test, _, [exp]} ->
          "\nwhile("<> (gen_exp exp) <>  ");"
        {:while, _, [bexp,[body]]} ->
          "while(" <> (gen_exp bexp) <> "){\n" <> (gen_body body) <> "\n}"
        # CRIAÇÃO DE NOVOS VETORES
        {{:., _, [Access, :get]}, _, [arg1,arg2]} ->
            name = gen_exp arg1
            index = gen_exp arg2
            "float #{name}[#{index}];"
        {:__shared__,_ , [{{:., _, [Access, :get]}, _, [arg1,arg2]}]} ->
          name = gen_exp arg1
          index = gen_exp arg2
          "__shared__ float #{name}[#{index}];"
        {:var, _ , [{var,_,[{:=, _, [{type,_,nil}, exp]}]}]} ->
          #IO.puts "aqui"
          gexp = gen_exp exp
          "#{to_string type} #{to_string var} = #{gexp};"
        {:var, _ , [{var,_,[{:=, _, [type, exp]}]}]} ->
            gexp = gen_exp exp
            "#{to_string type} #{to_string var} = #{gexp};"
        {:var, _ , [{var,_,[{type,_,_}]}]} ->
           "#{to_string type} #{to_string var};"
        {:var, _ , [{var,_,[type]}]} ->
           "#{to_string type} #{to_string var};"
        {:type, _ , [{_,_,[{_,_,_}]}]} ->
            ""
        {:type, _ , [{_,_,_}]} ->
            ""
        {:return, _, [arg]} ->
          "return (#{gen_exp(arg)});"
        {fun, _, args} when is_list(args)->
          #module = get_module_name()
          nargs=args
          |> Enum.map(&gen_exp/1)
          |> Enum.join(", ")

          "#{fun}(#{nargs});"

          #if(is_arg(fun)) do
           #   "#{fun}(#{nargs})\;"
          #else
          #  "#{module}_#{fun}(#{nargs})\;"
          #end
        {str,_ ,_ } ->
            "#{to_string str};"
        number when is_integer(number) or is_float(number) -> to_string(number)
        #string when is_string(string)) -> string #to_string(number)
      end
    end
    defp gen_exp(exp) do
      case exp do
         {{:., _, [Access, :get]}, _, [arg1,arg2]} ->
          name = gen_exp arg1
          index = gen_exp arg2
          "#{name}[#{index}]"
        {{:., _, [{struct, _, nil}, field]},_,[]} ->
          "#{to_string struct}.#{to_string(field)}"
        {{:., _, [{:__aliases__, _, [struct]}, field]}, _, []} ->
          "#{to_string struct}.#{to_string(field)}"
        {op, _, args} when op in [:+, :-, :/, :*, :<=, :<, :>, :>=, :&&, :||, :!,:!=,:==] ->
          case args do
            [a1] ->
              "(#{to_string(op)} #{gen_exp a1})"
            [a1,a2] ->
              "(#{gen_exp a1} #{to_string(op)} #{gen_exp a2})"
            end
        {var, _, nil} when is_atom(var) -> to_string(var)
        {fun, _, args} ->
          #module = get_module_name()
          nargs=args
          |> Enum.map(&gen_exp/1)
          |> Enum.join(", ")

          "#{fun}(#{nargs})"

      #    if(is_arg(fun)) do
      #      "#{fun}(#{nargs});"
      #    else
      #      "#{module}_#{fun}(#{nargs});"
      #    end

        number when is_integer(number) or is_float(number) -> to_string(number)
        string when is_binary(string)  -> "\"#{string}\""
      end

    end
    defp genIf([bexp, [do: then]]) do
      #raise "hell"

        gen_then([bexp, [do: then]])
    end
    defp genIf([bexp, [do: thenbranch, else: elsebranch]]) do
        # raise "hell"
         gen_then([bexp, [do: thenbranch]])
         <>
         "else{\n" <>
         (gen_body elsebranch) <>
         "\n}\n"
    end
    defp gen_then([bexp, [do: then]]) do
      "if(#{gen_exp bexp})\n" <>
      "{\n" <>
      (gen_body then) <>
      "\n}\n"
    end

####### types server

def get_module_name() do
  send(:types_server,{:module,self()})
  receive do
    {:module,name} -> name
    _         -> raise "Unknown message from types server."
  end
end

def is_arg(func) do
  send(:types_server,{:is_arg,func,self()})
  receive do
    {:is_arg,resp} -> resp
    _         -> raise "Unknown message from types server."
  end
end

def types_server(used,types, is_typed,module) do
   if (is_typed) do
    receive do
      {:is_arg, fun, pid} -> #IO.inspect fun
                             #IO.inspect types
                            if (nil == Map.get(types,fun)) do
                                send(pid,{:is_arg,false})
                                types_server(used,types,is_typed,module)
                            else
                                send(pid,{:is_arg,true})
                                types_server(used,types,is_typed,module)
                            end
      {:module,pid} -> send(pid,{:module,module})
              types_server(used,types,is_typed,module)
      {:check_var, _var, pid} ->
          send(pid,{:is_typed})
          types_server(used,types, is_typed,module)
      {:check_return,pid} ->  send(pid, Map.get(types,:return))
                              types_server(used,types, is_typed,module)
      {:kill} ->
            :ok
   end
  else
   receive do
    {:is_arg, fun, pid} -> if (nil==Map.get(types,fun)) do
              send(pid,{:is_arg,false})
              types_server(used,types,is_typed,module)
          else
              send(pid,{:is_arg,true})
              types_server(used,types,is_typed,module)
          end
    {:module,pid} -> send(pid,{:module,module})
              types_server(used,types,is_typed,module)
    {:check_var, var, pid} ->
      if (!Enum.member?(used,var)) do
        type = Map.get(types,String.to_atom(var))
        if(type == nil) do
          #IO.inspect var
          #IO.inspect types
          raise "Could not find type for variable #{var}. Please declare it using \"var #{var} type\""
        end
        send(pid,{:type,type})
        types_server([var|used],types,is_typed,module)
      else
        send(pid,{:alredy_declared})
        types_server(used,types,is_typed,module)
      end
    {:check_return,pid} -> send(pid, Map.get(types,:return))
                       types_server(used,types, is_typed,module)
    {:kill} ->
      :ok
    end

  end
end

#############3 end types server

###################
  def gen_kernel_call(kname,nargs,types) do
    gen_header(kname) <> gen_args(nargs,types) <> gen_call(kname,nargs)
  end

  def gen_header(fname) do
  "extern \"C\" void #{fname}_call(ErlNifEnv *env, const ERL_NIF_TERM argv[], ErlNifResourceType* type,ErlNifResourceType* ftype)
  {

    ERL_NIF_TERM list;
    ERL_NIF_TERM head;
    ERL_NIF_TERM tail;
    float **array_res;
    void **fun_res;

    const ERL_NIF_TERM *tuple_blocks;
    const ERL_NIF_TERM *tuple_threads;
    int arity;

    if (!enif_get_tuple(env, argv[1], &arity, &tuple_blocks)) {
      printf (\"spawn: blocks argument is not a tuple\");
    }

    if (!enif_get_tuple(env, argv[2], &arity, &tuple_threads)) {
      printf (\"spawn:threads argument is not a tuple\");
    }
    int b1,b2,b3,t1,t2,t3;

    enif_get_int(env,tuple_blocks[0],&b1);
    enif_get_int(env,tuple_blocks[1],&b2);
    enif_get_int(env,tuple_blocks[2],&b3);
    enif_get_int(env,tuple_threads[0],&t1);
    enif_get_int(env,tuple_threads[1],&t2);
    enif_get_int(env,tuple_threads[2],&t3);

    dim3 blocks(b1,b2,b3);
    dim3 threads(t1,t2,t3);

    list= argv[3];

"
  end
  def gen_call(kernelname,nargs) do
"   #{kernelname}<<<blocks, threads>>>" <> gen_call_args(nargs) <> ";
    cudaError_t error_gpu = cudaGetLastError();
    if(error_gpu != cudaSuccess)
     { char message[200];
       strcpy(message,\"Error kernel call: \");
       strcat(message, cudaGetErrorString(error_gpu));
       enif_raise_exception(env,enif_make_string(env, message, ERL_NIF_LATIN1));
     }
}
"
  end
  def gen_call_args(nargs) do
    "(" <> gen_call_args_(nargs-1) <>"arg#{nargs})"
  end
  def gen_call_args_(0) do
    ""
  end
  def gen_call_args_(n) do
    args = gen_call_args_(n-1)
    args <> "arg#{n},"
  end
  def gen_args(0,_l) do
    ""
  end
  def gen_args(n,[]) do
    args = gen_args(n-1,[])
    arg = gen_arg_matrix(n)
    args <> arg
  end
  def gen_args(n,[:matrex|t]) do
    args = gen_args(n-1,t)
    arg = gen_arg_matrix(n)
    args <> arg
  end
  def gen_args(n,[:int|t]) do
    args = gen_args(n-1,t)
    arg = gen_arg_int(n)
    args <> arg
  end
  def gen_args(n,[:float|t]) do
    args = gen_args(n-1,t)
    arg = gen_arg_float(n)
    args <> arg
  end
  def gen_args(n,[:double|t]) do
    args = gen_args(n-1,t)
    arg = gen_arg_double(n)
    args <> arg
  end
  def gen_args(n, [{ret,type}|t]) do
    args = gen_args(n-1,t)
    arg = gen_arg_fun(n,ret,type)
    args <> arg
  end
  def gen_arg_matrix(narg) do
    "  enif_get_list_cell(env,list,&head,&tail);
    enif_get_resource(env, head, type, (void **) &array_res);
    float *arg#{narg} = *array_res;
    list = tail;

  "
  end
  def gen_arg_fun(narg,ret,types) do
    #size = length(t)
    #IO.inspect t
    #{ret,types}=List.pop_at(t,size-1)
    #IO.inspect size
    #IO.inspect ret
    #IO.inspect types
    #raise "heel"
    r ="  enif_get_list_cell(env,list,&head,&tail);
    enif_get_resource(env, head, ftype, (void **) &fun_res);
      #{ret} (*arg#{narg})(#{to_arg_list(types)}) = (#{ret} (*)(#{to_arg_list(types)}))*fun_res;
      list = tail;

    "
    r
  end
  def gen_arg_int(narg) do
"  enif_get_list_cell(env,list,&head,&tail);
  int arg#{narg};
  enif_get_int(env, head, &arg#{narg});
  list = tail;

"
  end
  def gen_arg_float(narg) do
"  enif_get_list_cell(env,list,&head,&tail);
  double darg#{narg};
  float arg#{narg};
  enif_get_double(env, head, &darg#{narg});
  arg#{narg} = (float) darg#{narg};
  list = tail;

"
  end
  def gen_arg_double(narg) do
"  enif_get_list_cell(env,list,&head,&tail);
  double arg#{narg};
  enif_get_double(env, head, &darg#{narg});
  list = tail;

"
  end
end
