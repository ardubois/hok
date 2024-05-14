defmodule Hok do
  @on_load :load_nifs
  def load_nifs do
      :erlang.load_nif('./priv/gpu_nifs', 0)
      #IO.puts("ok")
  end

  defmacro hok(function) do
     #resp =  Macro.escape(quote(do: {:anon , unquote(function)}))
     #resp
    #IO.inspect function
    #raise "hell"
    {fname,type} = Hok.CudaBackend.gen_lambda("Elixir.App",function)
    result = quote do: Hok.load_lambda(unquote("Elixir.App"), unquote(fname), unquote(type))
    #IO.inspect result
    #raise "hell"
    result
  end


    defmacro gpufor({:<-, _ ,[var,tensor]},do: b)  do
      IO.inspect (quote do: Comp.comp(unquote(tensor), Hok.hok (fn (unquote(var)) -> (unquote b) end)))
      end

   defmacro gpufor({:<-,_, [var1, {:..,_, [b1, e1]}]}, {:<-,_, [var2, {:..,_, [b2, e2]}]},arr1,arr2,do: body) do
       r=      quote do: MM.comp2xy2D(unquote(arr1), unquote(arr2), unquote(e1), unquote(e2),
                                          Hok.hok (fn (unquote(arr1),
                                                       unquote(arr2),
                                                       unquote(var1),
                                                       unquote(var2)) -> (unquote body) end))
       #IO.inspect r
       #raise "hell"
       r
   end


  defmacro defmodule(header,do: body) do
    IO.inspect header
    #IO.inspect body
    {:__aliases__, _, [module_name]} = header


    code = Hok.CudaBackend.compile_module(module_name,body)

    file = File.open!("c_src/Elixir.#{module_name}.cu", [:write])
    IO.write(file, "#include \"erl_nif.h\"\n\n" <> code)
    File.close(file)
    {result, errcode} = System.cmd("nvcc",
        [ "--shared",
          "--compiler-options",
          "'-fPIC'",
          "-o",
          "priv/Elixir.#{module_name}.so",
          "c_src/Elixir.#{module_name}.cu"
  ], stderr_to_stdout: true)



  if ((errcode == 1) || (errcode ==2)) do raise "Error when compiling .cu file generated by Hok:\n#{result}" end

    ast_new_module = Hok.CudaBackend.gen_new_module(header,body)
    #IO.inspect ast_new_module
    ast_new_module


    #quote do: IO.puts "ok"
  end

  defmacro include(inc_list) do
    IO.inspect inc_list
    includes = inc_list
                |> Enum.map(fn {_,_,[module]} -> to_string(module) end)

    file = File.open!("c_src/Elixir.App.cu", [:write])
    IO.write(file, "#include \"erl_nif.h\"\n\n")
    Enum.map(includes, fn module ->   code = File.read!("c_src/Elixir.#{module}.cu")
                                          |>  String.split("\n")
                                          |>  Enum.drop(1)
                                          |> Enum.join("\n")
                                      IO.write(file, code)  end)
    File.close(file)

    {result, errcode} = System.cmd("nvcc",
        [ "--shared",
          "--compiler-options",
          "'-fPIC'",
          "-o",
          "priv/Elixir.App.so",
          "c_src/Elixir.App.cu"
  ], stderr_to_stdout: true)


  if ((errcode == 1) || (errcode ==2)) do raise "Error when compiling .cu file generated by Hok:\n#{result}" end


  end

  #####################
  #####
  #####  gptype macro ##########
  #####
  ##########################

  defmacro deft({func,_,[type]}) do

    if (nil == Process.whereis(:gptype_server)) do
      pid = spawn_link(fn -> gptype_server() end)
      Process.register(pid, :gptype_server)
    end
    send(:gptype_server,{:add_type, func,type_to_list(type)})
    #IO.inspect(type_to_list(type))
    quote do
    end
  end
  def gptype_server(), do: gptype_server_(Map.new())
  defp gptype_server_(map) do
    receive do
      {:add_type, fun, types}  -> map=Map.put(map,fun, types)
                              gptype_server_(map)
      {:get_type, pid,fun} -> type=Map.get(map,fun)
                              send(pid,{:type,fun,type})
                              gptype_server_(map)
      {:kill}               -> :dead
    end
  end
  defp type_to_list({:integer,_,_}), do: [:int]
  defp type_to_list({:unit,_,_}), do: [:unit]
  defp type_to_list({:float,_,_}), do: [:float]
  defp type_to_list({:gmatrex,_,_}), do: [:matrex]
  defp type_to_list([type]), do: [type_to_list(type)]
  defp type_to_list({:~>,_, [a1,a2]}), do: type_to_list(a1) ++ type_to_list(a2)
  defp type_to_list({x,_,_}), do: raise "Unknown type constructor #{x}"
  def is_typed?() do
    nil != Process.whereis(:gptype_server)
  end
  def get_type_kernel(fun_name) do
    send(:gptype_server,{:get_type, self(),fun_name})
    receive do
      {:type,fun,type} -> if fun == fun_name do
                                send(:gptype_server,{:kill})
                                type
                          else
                                raise "Asked for #{fun_name} got #{fun}"
                          end
      end

    end
    def get_type_fun(fun_name) do
      send(:gptype_server,{:get_type, self(),fun_name})
      receive do
        {:type,fun,type} -> if fun == fun_name do
                                  type
                            else
                                  raise "Asked for #{fun_name} got #{fun}"
                            end
        end

      end

  #############################################
  ###########
  #######    Hok macro
  #######
  #####################



  defmacro defk(header, do: body) do
    {fname, comp_info, para} = header

    caller_st = __CALLER__
    module_name = to_string caller_st.module

    {delta,is_typed}  = if(is_typed?()) do
              types = get_type_kernel(fname)
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




   #inf_types = Hok.TypeInference.infer_types(delta,body)

   inf_types = Hok.TypeInference.type_check(delta,body)

   #IO.inspect inf_types
  # raise "hell"

   param_list = para
      |> Enum.map(fn {p, _, _}-> gen_para(p,Map.get(inf_types,p)) end)
      |> Enum.join(", ")

   types_para = para
      |>  Enum.map(fn {p, _, _}-> Map.get(inf_types,p) end)



  #raise "hell"

   inf_types = if is_typed do %{} else inf_types end
   #IO.inspect inf_types
   #raise "hell"
   cuda_body = Hok.CudaBackend.gen_cuda(body,inf_types,is_typed)
   k = Hok.CudaBackend.gen_kernel(fname,param_list,cuda_body)
   accessfunc = Hok.CudaBackend.gen_kernel_call(fname,length(types_para),Enum.reverse(types_para))
   if(File.exists?("c_src/#{module_name}.cu")) do
    file = File.open!("c_src/#{module_name}.cu", [:append])
    IO.write(file, "\n" <> k <> "\n\n" <> accessfunc)
  else
    file = File.open!("c_src/#{module_name}.cu", [:write])
    IO.write(file, "#include \"erl_nif.h\"\n\n" <> k <> "\n\n" <> accessfunc)
    File.close(file)
  end
   #IO.puts k
   #IO.puts accessfunc

  {result, errcode} = System.cmd("nvcc",
  ["--shared",
  "--compiler-options",
  "'-fPIC'",
  "-o",
  "priv/#{module_name}.so",
  "c_src/#{module_name}.cu"
  ], stderr_to_stdout: true)

  File.rename("c_src/#{module_name}.cu","c_src/#{module_name}_gp.cu")

  if ((errcode == 1) || (errcode ==2)) do raise "Error when compiling .cu file generated by Hok:\n#{result}" end


  para = if is_list(List.last(para)) do List.delete_at(para,length(para)-1) else para end
  para = para
    |> Enum.map(fn {p, b, c}-> {String.to_atom("_" <> to_string(p)),b,c} end)


   quote do
      def unquote({fname,comp_info, para})do
        raise "A kernel can only be executed with Hok.spawn"
      end
    end
end

defp gen_para(p,:matrex) do
  "float *#{p}"
end
defp gen_para(p,:float) do
  "float #{p}"
end
defp gen_para(p,:int) do
  "int #{p}"
end
defp gen_para(p, list) when is_list(list) do
  size = length(list)

  {ret,type}=List.pop_at(list,size-1)
  #IO.inspect list
  #IO.inspect ret
  #IO.inspect type
  #raise "hell"
  r="#{ret} (*#{p})(#{to_arg_list(type)})"
  r

end
defp to_arg_list([t]) do
  "#{t}"
end
defp to_arg_list([v|t]) do
  "#{v}," <> to_arg_list(t)
end

################################################
############
############## gpdef macro
########
#################

defmacro deff(header, do: body) do
  {fname, comp_info, para} = header

  caller_st = __CALLER__
  module_name = to_string caller_st.module


  {delta,is_typed,fun_type}  = if(is_typed?()) do

    types = get_type_fun(fname)
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

  inf_types = Hok.TypeInference.infer_types(delta,body)

  fun_type = if is_typed do fun_type else Map.get(inf_types,:return) end

  param_list = para
    |> Enum.map(fn {p, _, _}-> gen_para(p,Map.get(inf_types,p)) end)
    |> Enum.join(", ")



 cuda_body = Hok.CudaBackend.gen_cuda(body,inf_types,is_typed)
 k =        Hok.CudaBackend.gen_function(fname,param_list,cuda_body,fun_type)
 ptr =      Hok.CudaBackend.gen_function_ptr(fname)
 get_ptr = Hok.CudaBackend.gen_get_function_ptr(fname)



 #accessfunc = Hok.CudaBackend.gen_kernel_call(fname,length(types_para),Enum.reverse(types_para))
 if(File.exists?("c_src/#{module_name}.cu")) do
  file = File.open!("c_src/#{module_name}.cu", [:append])
  IO.write(file, "\n" <> k <> "\n\n" <> ptr <> "\n\n" <> get_ptr <> "\n\n")
else
  file = File.open!("c_src/#{module_name}.cu", [:write])
  IO.write(file, "#include \"erl_nif.h\"\n\n" <> k <> "\n\n" <> ptr <> "\n\n" <> get_ptr <> "\n\n")
  File.close(file)
end
 #IO.puts k
 #IO.puts accessfunc
 #para = if is_list(List.last(para)) do List.delete_at(para,length(para)-1) else para end
 para = para
  |> Enum.map(fn {p, b, c}-> {String.to_atom("_" <> to_string(p)),b,c} end)


 quote do
    def unquote({fname,comp_info, para})do
      raise "A gp function can only be called in kernels"
    end
  end
end

  def create_ref_nif(_matrex) do
    raise "NIF create_ref_nif/1 not implemented"
end
def new_pinned_nif(_list,_length) do
  raise "NIF new_pinned_nif/1 not implemented"
end
def new_gmatrex_pinned_nif(_array) do
  raise "NIF new_gmatrex_pinned_nif/1 not implemented"
end
def new_pinned(list) do
  size = length(list)
  {new_pinned_nif(list,size), {1,size}}
end
def new_gmatrex(%Matrex{data: matrix} = a) do
  ref=create_ref_nif(matrix)
  {ref, Matrex.size(a)}
end
def new_gmatrex({array,{l,c}}) do
  ref=new_gmatrex_pinned_nif(array)
  {ref, {l,c}}
end

def new_gmatrex(r,c) do
  ref=new_ref_nif(c)
  {ref, {r,c}}
  end

def new_ref_nif(_matrex) do
  raise "NIF new_ref_nif/1 not implemented"
end
def synchronize_nif() do
  raise "NIF new_ref_nif/1 not implemented"
end
def synchronize() do
  synchronize_nif()
end
def new_ref(size) do
ref=new_ref_nif(size)
{ref, {1,size}}
end
def get_matrex_nif(_ref,_rows,_cols) do
raise "NIF get_matrex_nif/1 not implemented"
end
def get_gmatrex({ref,{rows,cols}}) do
%Matrex{data: get_matrex_nif(ref,rows,cols)}
end

def load_kernel_nif(_module,_fun) do
  raise "NIF load_kernel_nif/2 not implemented"
end
def load_fun_nif(_module,_fun) do
  raise "NIF load_fun_nif/2 not implemented"
end
def load_type(kernel) do
  case Macro.escape(kernel) do
    {:&, [],[{:/, [], [{{:., [], [module, kernelname]}, [no_parens: true], []}, _nargs]}]} ->


              bytes = File.read!("c_src/#{module}.types")
              map = :erlang.binary_to_term(bytes)

              module_name=String.slice("#{module}",7..-1//1) # Eliminates Elixir.

              map["#{module_name}_#{kernelname}"]

    _ -> raise "Hok.build: invalid kernel"
  end
end
def load(kernel) do
  case Macro.escape(kernel) do
    {:&, [],[{:/, [], [{{:., [], [module, kernelname]}, [no_parens: true], []}, _nargs]}]} ->


             # IO.puts module
              #raise "hell"
              module_name=String.slice("#{module}",7..-1//1) # Eliminates Elixir.
              Hok.load_kernel_nif(to_charlist("Elixir.App"),to_charlist("#{module_name}_#{kernelname}"))

    _ -> raise "Hok.build: invalid kernel"
  end
end
def load_fun(fun) do
  case Macro.escape(fun) do
    {:&, [],[{:/, [], [{{:., [], [module, funname]}, [no_parens: true], []}, _nargs]}]} ->

              module_name=String.slice("#{module}",7..-1//1) # Eliminates Elixir.

              Hok.load_fun_nif(to_charlist("Elixir.App"),to_charlist("#{module_name}_#{funname}"))
    _ -> raise "Hok.invalid function"
  end
end
def load_lambda(module,lambda,type) do
  {:anon, Hok.load_fun_nif(to_charlist(module),to_charlist(lambda)), type}
end
#####################
defp process_args([{:anon,ref,_type}|t1]) do
  [ref | process_args(t1)]
end
defp process_args([{matrex,{_rows,_cols}}| t1]) do
  [matrex | process_args(t1)]
end
defp process_args([arg|t1]) when is_function(arg) do
  [load_fun(arg)| process_args(t1)]
end
defp process_args([arg|t1]) do
  [arg | process_args(t1)]
end
defp process_args([]), do: []

############################

def type_check_args(kernel,narg, [:float | t1], [v|t2]) do
    if is_float(v) do
      type_check_args(kernel,narg+1,t1,t2)
    else
      raise "#{kernel}: argument #{narg} should have type float."
    end
end
def type_check_args(kernel,narg, [:int | t1], [v|t2]) do
  if is_integer(v) do
    type_check_args(kernel,narg+1,t1,t2)
  else
    raise "#{kernel}: argument #{narg} should have type float."
  end
end
def type_check_args(kernel,narg, [{rt , ft} | t1], [{:anon, _ref, { art , aft}} |t2]) do
  if rt == art do
    type_check_args("anonymous",0,ft,aft)
    type_check_args(kernel,narg+1,t1,t2)
  else
    raise "#{kernel}: anonymous function has return type #{art}, was excpected to have type #{rt}."
  end
end
def type_check_args(kernel,narg, [{rt , ft} | t1], [func |t2]) when is_function(func) do
   {art,aft} = load_type(func)
   f_name= case Macro.escape(func) do
    {:&, [],[{:/, [], [{{:., [], [module, f_name]}, [no_parens: true], []}, _nargs]}]} -> f_name
     _ -> raise "Argument to spawn should be a function."

  if rt == art do
      type_check_args(f_name,0,ft,aft)
      type_check_args(kernel,narg+1,t1,t2)
    else
      raise "#{kernel}: #{f_name} function has return type #{art}, was excpected to have type #{rt}."
    end
end
def type_check_args(_k,_narg,[],[]), do: []
def type_check_args(k,narg,a,v), do: raise "Wrong number of arguments when calling #{k}."

#######################
def spawn_nif(_k,_t,_b,_l) do
  raise "NIF spawn_nif/1 not implemented"
end
def spawn(k,t,b,l) when is_function(k) do

  f_name= case Macro.escape(k) do
    {:&, [],[{:/, [], [{{:., [], [module, f_name]}, [no_parens: true], []}, _nargs]}]} -> f_name
     _ -> raise "Argument to spawn should be a function."


    pk=load(k)

    tk = load_type(k)

    type_check_args(f_name,1,tk,l)
    args = process_args(l)

    spawn_nif(pk,t,b,args)

end
def spawn(k,t,b,l) do
  raise "First argument of spawn must be a function."
  #spawn_nif(k,t,b,Enum.map(l,&get_ref/1))
end
def get_ref({ref,{_rows,_cols}}) do
  ref
end
def get_ref(e) do
  e
end
end
