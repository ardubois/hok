defmodule Hok.TypeInference do
  def type_check(map,body) do

    #body = Hok.TypeInference.add_return(map,body)

    types = infer_types(map,body)
    notinfer = not_infered(Map.to_list(types))
    if(length(notinfer)>0) do
      #IO.puts "Not infered:"
     # IO.inspect notinfer
     # IO.puts "Second pass:"
      types2 = infer_types(types,body)
      notinfer2 = not_infered(Map.to_list(types2))
      if (length(notinfer)==length(notinfer2)) do
        #IO.inspect notinfer2
        #raise "Could not find types! Please use type annotations of the form: var x float, where x is an identifier"

        #IO.puts "Could not find types, choosing type float.."
        IO.inspect types
        raise "Could not find types."
        #map =for {var, type} <- types, into: %{} do if(type == :none)do {var, :float} else {var,type}  end end
        #IO.inspect map
        #raise "hell"
        map
      else
        type_check(types2,body)
      end
    else
      types
    end
  end
  defp not_infered([]), do: []
  defp not_infered([h|t]) do
    case h do
      {v, :none}  -> [{v, :none} |not_infered(t) ]
      {v, {:none, list}} -> [{v ,{:none, list}}| not_infered(t)]
      {v,{rt, list}} -> fil = Enum.filter(list, fn x -> x == :none end)
                        if fil == [] do
                          not_infered(t)
                        else
                          [{v,{rt, list}} | not_infered(t)]
                        end
      {_,_} -> not_infered(t)
    end
  end
  #defmacro tinf(header, do: body) do
  # {_fname, _, para} = header
  # map = para
  # |> Enum.map(fn({p, _, _}) -> p end)
  # |> Map.new(fn x -> {x,:none} end)
  ## IO.inspect body
  # nmap = infer_types(map,body)
  # #IO.inspect nmap
  # :ok
  #end

  ########################### adds return statement to functions that return an expression

  def add_return(map,body) do
    if map[:return] == nil do
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
                      {:do, check_return(exp)}
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
          {:if, info, [ exp,[do: block]]} -> [{:if, info, [ exp,[do: check_return block]]}]
          {:if, info, [ exp,[do: block, else: belse ]]} -> [{:if, info, [ exp,[do: check_return(block), else: check_return(belse) ]]}]
          {:=, info, args} ->  [ {:=, info, args},  {:return,[],[:unit]}]
          _ -> if is_exp?(com) do
                      [{:return,[],[com]}]
                  else
                    [com]
                  end
              
    end
  end
  defp check_return(com) do
    case com do
          {:return,_,_} -> com
          {:if, info, [ exp,[do: block]]} -> {:if, info, [ exp,[do: check_return block]]}
          {:if, info, [ exp,[do: block, else: belse ]]} -> {:if, info, [ exp,[do: check_return(block), else: check_return(belse) ]]}
          {:=, info, args} ->  [ {:=, info, args},  {:return,[],[:unit]}]
           _ -> if is_exp?(com) do
                      {:return,[],[com]}
                  else
                    com
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


  def get_default_type() do
    send(:types_ast_server,{:get_default_type, self()})
    receive do
               {:default_type, type} -> if (is_atom(type)) do
                                            type
                                        else
                                          IO.inspect type
                                          case type[:default] do
                                            nil -> case type[:a] do
                                                    nil -> raise "Error in type inference, no default type defined!"
                                                    t -> t
                                                   end 
                                            t -> t       
                                          end
                                        end
               h    -> raise "Unknown message from type server #{inspect h}"
    end
  end
#######################################################33

  def infer_types(map,body) do
    #IO.puts "#####"
    #IO.inspect body1
    #body = add_return(map,body1)

    #IO.inspect body
    #IO.puts "####"
    #raise "hell"
    case body do
        {:__block__, _, _code} ->
          infer_block(map,body)
        {:do, {:__block__,pos, code}} ->
          infer_block(map, {:__block__, pos,code})
        {:do, exp} ->
          infer_command(map,exp)
        {_,_,_} ->
          infer_command(map,body)
     end
  end
  defp infer_block(map,{:__block__, _, code}) do
    Enum.reduce(code, map, fn com, acc -> infer_command(acc,com) end)
  end
  defp infer_header_for(map,header) do
    case header do
      {:in, _,[{var,_,nil},{:range,_,[arg1]}]} ->
        map
         |> Map.put(var,:int)
         |> set_type_exp(:int,arg1)
      {:in, _,[{var,_,nil},{:range,_,[arg1,arg2]}]} ->
        map
        |> Map.put(var,:int)
        |> set_type_exp(:int,arg1)
        |> set_type_exp(:int,arg2)
      {:in, _,[{var,_,nil},{:range,_,[arg1,arg2,step]}]} ->
        map
        |> Map.put(var,:int)
        |> set_type_exp(:int,arg1)
        |> set_type_exp(:int,arg2)
        |> set_type_exp(:int,step)
    end
  end
  defp infer_command(map,code) do
      case code do
          {:for,_,[param,[body]]} ->
           map
            |> infer_header_for(param)
            |> infer_types(body)
          {:do_while, _, [[doblock]]} ->
            infer_types(map,doblock)
          {:do_while_test, _, [exp]} ->
            set_type_exp(map,:int,exp)
          {:while, _, [bexp,[body]]} ->
            map
            |> set_type_exp(:int,bexp)
            |> infer_types(body)
          # CRIAÇÃO DE NOVOS VETORES
          {{:., _, [Access, :get]}, _, [arg1,arg2]} ->
             array = get_var arg1
             map
             |> Map.put(array,:none)
             |> set_type_exp(:int,arg2)
          {:__shared__,_ , [{{:., _, [Access, :get]}, _, [arg1,arg2]}]} ->
             array = get_var arg1
             map
             |> Map.put(array,:none)
             |> set_type_exp(:int,arg2)
          # assignment
          {:=, _, [{{:., _, [Access, :get]}, _, [{array,_,_},acc_exp]}, exp]} ->
            case get_or_insert_var_type(map,array) do
              {map,:none} -> type = get_default_type()
                             case type do
                              :none -> raise "Default type = :none"
                              :int -> map
                                  |> Map.put(array,:tint)
                                  |> set_type_exp(:int, acc_exp)
                                  |> set_type_exp(:int,exp)
                              :float -> map
                                    |> Map.put(array,:tfloat)
                                    |> set_type_exp(:int, acc_exp)
                                    |> set_type_exp(:float,exp)
                              :double -> map
                                      |> Map.put(array,:tdouble)
                                      |> set_type_exp(:int, acc_exp)
                                      |> set_type_exp(:double,exp)
                             end
              {map,:tint} -> map
                          |> set_type_exp(:int, acc_exp)
                          |> set_type_exp(:int,exp)
              {map,:tfloat} -> map
                          |> set_type_exp(:int, acc_exp)
                          |> set_type_exp(:float,exp)
              {map,:tdouble} -> map
                          |> set_type_exp(:int, acc_exp)
                          |> set_type_exp(:double,exp)
            end

          {:=, _, [var, exp]} ->
            var = get_var(var)
            case get_or_insert_var_type(map,var) do
              {map, :none} ->
                    type_exp = find_type_exp(map,exp)
                    if(type_exp != :none) do
                      map
                      |> Map.put(var,type_exp)
                      |> set_type_exp(type_exp,exp)
                    else
                      infer_type_fun(map,exp) #  hak to infer the types of arguments in case is a function call
                    end
              {map,var_type} ->

                  set_type_exp(map,var_type,exp)

            end
          {:if, _, if_com} ->
               infer_if(map,if_com)
          {:var, _ , [{var,_,[{:=, _, [{type,_,nil}, exp]}]}]} ->
                map
                |> Map.put(var,type)
                |> set_type_exp(type,exp)
          {:var, _ , [{var,_,[{:=, _, [type, exp]}]}]} ->
                map
                |> Map.put(var,type)
                |> set_type_exp(type,exp)
          {:var, _ , [{var,_,[{type,_,_}]}]} ->
                map
                |> Map.put(var,type)
          {:var, _ , [{var,_,[type]}]} ->
                map
                |> Map.put(var,type)
          {:type, _ , [{var,_,[{type,_,_}]}]} ->
                  map
                  |> Map.put(var,type)
          {:type, _ , [{var,_,[type]}]} ->
                  map
                  |> Map.put(var,type)

          {:return,_,[arg]} ->
            case map[:return] do
              :none ->
                  inf_type = find_type_exp(map,arg)
                 # IO.inspect "Aqueee #{inspect inf_type}"
                  case inf_type do
                      :none -> map
                       found_type ->  map = set_type_exp(map,found_type,arg)
                                      map =Map.put(map,:return,found_type)
                                      map
                                     # IO.inspect map
                  end
                nil -> raise "Function must have a return."
                found_type -> #IO.inspect arg
                    set_type_exp(map,found_type,arg)

            end

          {fun, _, args} when is_list(args)->
            #IO.puts "case function"
           # IO.inspect fun
           # IO.inspect args
          #  IO.puts "#########"
           # raise "hell"
             type_fun = map[fun]
            # IO.inspect type_fun
              if( type_fun == nil) do
                 # Enum.reduce(args,map, fn v,acc -> infer_type_exp(acc,v) end)
                 {map, infered_type}= infer_types_args(map,args,[])
                  Map.put(map,fun, {:unit,infered_type})
              else
                  case type_fun do
                    :none ->      {map, infered_type}= infer_types_args(map,args,[])
                                  Map.put(map,fun, {:unit,infered_type})
                    {ret,type} -> IO.puts "set type args call fun: #{fun}, args: #{inspect args}"
                                  IO.puts "TYPE: return #{ret} args: #{inspect type}"
                                  {map, infered_type} = set_type_args(map,type,args,[])
                                  case ret do
                                    :none -> Map.put(map,fun, {:unit, infered_type})
                                    :unit -> Map.put(map,fun, {:unit, infered_type})
                                    t -> raise "Function #{fun} has return type #{t} as is being used in context :unit"
                                  end
                  end
              end
          number when is_integer(number) or is_float(number) -> raise "Error: number is a command"
          {_str,_ ,_ } ->
            #IO.puts "yo"
            #raise "Is #{str}  a command???"
            map
          #string when is_string(string)) -> string #to_string(number)
      end
end
###################  Auxiliary functions for infering type of function call

defp set_type_args(map,[],[],type), do: {map,type}
defp set_type_args(map, [:none], a1, newtype) when is_tuple a1 do
  t=find_type_exp(map,a1)
   case t do
      :none -> {map,newtype ++ [:none]}
      nt     -> map = set_type_exp(map,nt,a1)
                {map, newtype ++[nt]}
   end
end
defp set_type_args(map,[t1 | _types], a1, newtype ) when is_tuple a1 do
  map=set_type_exp(map,t1,a1)
  {map, newtype ++ [t1]}
end
defp set_type_args(map,[:none|tail],[a1 |args], newtype) do
   t=find_type_exp(map,a1)
   case t do
      :none -> set_type_args(map,tail, args, newtype ++ [:none])
      nt     -> map = set_type_exp(map,nt,a1)
                set_type_args(map,tail, args, newtype ++[nt])
   end
end
defp set_type_args(map,[t1 | types], [a1|args], newtype ) do
  map=set_type_exp(map,t1,a1)
  set_type_args(map,types,args, newtype ++ [t1])
end
defp infer_types_args(map,[],type), do: {map,type}
defp infer_types_args(map,[h|tail],type) do
   t=find_type_exp(map,h)
   #IO.inspect h
   #IO.inspect t
   case t do
      :none -> infer_types_args(map,tail, type ++ [:none])
      nt     -> map = set_type_exp(map,nt,h)
                infer_types_args(map,tail, type ++[nt])
   end
end
####################################################
defp get_or_insert_var_type(map,var) do
  var_type = Map.get(map,var)
  if(var_type == nil) do
      map = Map.put(map,var,:none)
      {map,:none}
  else
    {map,var_type}
  end
end
defp get_var(id) do
    case id do
      {{:., _, [Access, :get]}, _, [{array,_,_},_arg2]} ->
        #IO.inspect "Aqui #{array}"
        array
      {var, _, nil} when is_atom(var) -> var
    end
end

################## infering ifs

defp infer_if(map,[bexp, [do: then]]) do
    map
    |> set_type_exp(:int, bexp)
    |> infer_types(then)
end
defp infer_if(map,[bexp, [do: thenbranch, else: elsebranch]]) do
   map
    |> set_type_exp(:int,bexp)
    |> infer_types(thenbranch)
    |> infer_types(elsebranch)
end

###################################################################

defp set_type_exp(map,type,exp) do
    case exp do
      {{:., info, [Access, :get]}, _, [arg1,arg2]} ->
       case type do
         :int -> map
             |> Map.put(get_var(arg1),:tint)
             |> set_type_exp(:int,arg2)
         :float -> map
             |> Map.put(get_var(arg1),:tfloat)
             |> set_type_exp(:int,arg2)
         :double -> map
             |> Map.put(get_var(arg1),:tdouble)
             |> set_type_exp(:int,arg2)
         _ -> raise "Error: location (#{inspect info}), unknown type #{inspect type}"

       end

      {{:., _, [{_struct, _, nil}, _field]},_,[]} ->
        map
      {{:., _, [{:__aliases__, _, [_struct]}, _field]}, _, []} ->
        map
      {op, info, [a1,a2]} when op in [:+, :-] and type == :matrex ->
        t1 = find_type_exp(map,a1)
        t2 = find_type_exp(map,a2)
        case t1 do
          :none ->  case t2 do
                      :none -> map
                      :int  -> set_type_exp(map,:matrex,a1)
                      :matrex -> set_type_exp(map,:int,a1)
                    end
          :int ->
              map=set_type_exp(map,:int,a1)
              set_type_exp(map,:matrex,a2)
          :matrex ->  map=set_type_exp(map,:matrex,a1)
                      set_type_exp(map,:int,a2)
          tt  -> raise "Exp #{inspect a1} (#{inspect info}) has type #{tt} and should have type #{type}"
        end
      {op, _info, args} when op in [:+, :-, :/, :*] ->
          case args do
           [a1] ->
         #   if(type != :int && type != :float) do
          #    raise "Operaotr (-) (#{inspect info}) is being used in a context #{type}"
           # end
            set_type_exp(map,type,a1)
           [a1,a2] ->
            #if(type != :int && type != :float) do
             # raise "Operaotr11 (#{inspect op}) (#{inspect info}) is being used in a context #{inspect type}"
            #end
            t1 = find_type_exp(map,a1)
            t2 = find_type_exp(map,a2)
            case t1 do
                :none ->
                    map = set_type_exp(map,type,a1)
                    case t2 do
                       :none -> set_type_exp(map,type,a2)
                       _     -> set_type_exp(map,t2,a2)
                    end
                _->
                  map = set_type_exp(map,t1,a1)
                  case t2 do
                    :none -> set_type_exp(map,type,a2)
                    _     -> set_type_exp(map,t2,a2)
                  end
              end
          end
      {op, info, [arg1,arg2]} when op in [:!=,:==] ->
        if(type != :int)  do
          raise "Operaotr (#{inspect op}) (#{inspect info}) is being used in a context #{inspect type}"
        end
        t1 = find_type_exp(map,arg1)
        t2 = find_type_exp(map, arg2)
        case t1 do
          :none -> case t2 do
                      :none ->  map
                      ntype ->  set_type_exp(map,ntype,arg1)
                                set_type_exp(map,ntype,arg2)
                    end
          ntype ->  set_type_exp(map,ntype,arg1)
                    case t2 do
                        :none -> map = set_type_exp(map,ntype,arg2)
                                 map
                        ntype2 -> if ntype != ntype2 do
                                      raise "Operator #{inspect op} (#{inspect info}) is applyed to type #{t1} and type #{t2}."
                                  else
                                      set_type_exp(map,ntype2,arg2)
                                  end
                    end
        end
        {op, info, [arg1,arg2]} when op in [ :<=, :<, :>, :>=] ->
          if(type != :int)  do
            raise "Operaotr (#{inspect op}) (#{inspect info}) is being used in a context #{inspect type}"
          end
          t1 = find_type_exp(map,arg1)
          t2 = find_type_exp(map, arg2)
          case t1 do
            :none -> case t2 do
                        :none ->  map
                        ntype ->  set_type_exp(map,ntype,arg2)
                      end
            ntype ->  map = set_type_exp(map,ntype,arg1)
                      case t2 do
                          :none -> map
                          ntype2 -> set_type_exp(map,ntype2,arg2)
                      end
          end
        #case t1 do
        #  :none ->
        #    map = set_type_exp(map,type,arg1)
        #    case t2 do
        #       :none -> set_type_exp(map,type,arg2)
        #       _     -> set_type_exp(map,t2,arg2)
        #    end
        #  _->
        #    map = set_type_exp(map,t1,arg1)
        #    case t2 do
        #      :none -> set_type_exp(map,type,arg2)
        #      _     -> set_type_exp(map,t2,arg2)
        #    end
        #end
      {:!, info, [arg]} ->
          if (type != :int) do
            raise "Operator (!) (#{inspect info}) is being used in a context #{inspect type}"
          end
          set_type_exp(map,:int,arg)
      {op, inf, args} when op in [ :&&, :||] ->
           if(type != :int)do
            raise "Op #{op} (#{inspect inf}) is being used in a context: #{inspect type}"
           end
          case args do
              [a1] ->
                set_type_exp(map,:int,a1)
              [a1,a2] ->
               map
                |> set_type_exp(:int,a1)
                |> set_type_exp(:int,a2)

          end
      {var, _info, nil} when is_atom(var) ->
        if (Map.get(map,var)==nil) do
          raise "Error: variable #{inspect var} is used in expression before being declared"
        end

        if (Map.get(map,var) == :none) do
          Map.put(map,var,type)
        else
           if(Map.get(map,var) != type) do
             if type == :int do
              raise "Error: variable #{inspect var} should have type integer"
             else
              map
             end
           else
             map
           end
        end
      {fun, _, args} when is_list(args)->
         type_fun = Map.get(map,fun)
         if( type_fun == nil) do
            #Enum.reduce(args,map, fn v,acc -> infer_type_exp(acc,v) end)
            {map, infered_type}= infer_types_args(map,args,[])
             map = Map.put(map,fun, {type,infered_type})
             map
          else
            case type_fun do
              :none ->      {map, infered_type}= infer_types_args(map,args,[])
                            map = Map.put(map,fun, {type,infered_type})
                            map
              {ret,type_args} -> # IO.puts "set type args call fun: #{fun}, args: #{inspect args}" 
                              {map, infered_type} = set_type_args(map,type_args,args,[])
                              cond do
                                ret == type -> Map.put(map,fun, {type, infered_type})
                                ret == :none -> Map.put(map,fun, {type, infered_type})
                                true           -> raise "Function #{fun} has return type #{ret} and is being used in an #{type} context."
                              end

            end
        end
        #Enum.reduce(args,map, fn v,acc -> infer_type_exp(acc,v) end)
      {_fun, _, _noargs} ->
        map
      :unit ->
        if(type == :unit) do
          map
        else
          raise ("Type error: :unit is being used in a context of type #{inspect type}")
        end  
      float when  is_float(float) ->
        if(type == :float) do
          map
        else
          raise ("Type error: #{inspect float} is being used in a context of type #{inspect type}")
        end
      int   when  is_integer(int) ->
        if(type == :int || type == :float) do
          map
        else
          raise ("Type error: #{inspect int} is being used in a context of type #{inspect type}")
        end
      string when is_binary(string)  ->
        if(type == :string) do
          map
        else
          raise ("Type error: #{inspect string} is being used in a context of type #{inspect type}")
        end
   end
  end
#  defp infer_type_exp(map,exp) do
 #   type = find_type_exp(map,exp)
  #  set_type_exp(map,type,exp)
  #end
  defp infer_type_fun(map,exp) do
      case exp do
        {fun, _, args} when is_list(args)->
          type_fun = Map.get(map,fun)
          if( type_fun == nil) do
             #Enum.reduce(args,map, fn v,acc -> infer_type_exp(acc,v) end)
             {map, infered_type}= infer_types_args(map,args,[])
              map = Map.put(map,fun, {:none,infered_type})
              map
           else
             case type_fun do
               :none ->      {map, infered_type}= infer_types_args(map,args,[])
                             map = Map.put(map,fun, {:none,infered_type})
                             map
               {ret,type_args} -> #IO.puts "set type args call fun: #{fun}, args: #{inspect args}"
                                  {map, infered_type} = set_type_args(map,type_args,args,[])
                                  Map.put(map,fun, {ret, infered_type})

             end
          end




        _ -> map
       end
  end


  def infer_type_exp(map,exp) do
    type = find_type_exp(map,exp)
    if (type != :none) do
      set_type_exp(map,type,exp)
    else
      map
    end
end

  defp find_type_exp(map,exp) do
      case exp do
         {{:., info_, [Access, :get]}, _, [{arg1,_,_},_arg2]} ->
           case map[arg1] do
             :tint -> :int
             :tdouble -> :double
             :tfloat -> :float
             nil -> type = get_default_type()
                    type  
            :none -> type = get_default_type()
                     type 
             ttt -> raise "Found type #{inspect ttt} for id #{inspect arg1} (#{inspect info_})"
           end

        {{:., _, [{_struct, _, nil}, _field]},_,[]} ->
           :int
        {{:., _, [{:__aliases__, _, [_struct]}, _field]}, _, []} ->
          :int
        {op,info, args} when op in [:+, :-, :/, :*] ->
          case args do
            [a1] ->
              find_type_exp(map,a1)
            [a1,a2] ->
              t1 = find_type_exp(map,a1)
              t2 = find_type_exp(map,a2)
              case t1 do
                :none -> t2
                :int  -> case t2 do
                           :int -> :int
                           :float -> :float
                           :double -> :double
                           :none -> :none
                           _  -> raise "Incompatible operands (#{inspect info}: op (#{inspect op}) applyed to  type #{inspect t2}"
                          end
                :float -> :float
                :double -> :double
                :tfloat -> :tfloat
                :tdouble-> :tdouble
                :tint -> :tint
                _ -> raise "Incompatible operands (#{inspect info}: op (#{inspect op}) applyed to  type #{inspect t1}"

              end
          end
        {op, _, _args} when op in [ :<=, :<, :>, :>=, :&&, :||, :!,:!=,:==] ->
          :int
        {var, _, nil} when is_atom(var) ->
          if (Map.get(map,var)==nil) do
            raise "Error: variable #{inspect var} is used in expression before being declared"
          else
            Map.get(map,var)
          end
        :unit -> :unit
        {fun, _, _args} ->
            #IO.puts "aqui"
            #raise "hell"
            type_fun = map[fun]
            case type_fun do
                nil -> :none
                :none -> :none
                {ret,_type} -> ret
            end
        float when  is_float(float) -> :float
        int   when  is_integer(int) -> :int
        string when is_binary(string)  -> :string
      end

    end


end
