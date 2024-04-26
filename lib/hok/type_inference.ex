defmodule Hok.TypeInference do
  def type_check(map,body) do
    types = infer_types(map,body)
    notinfer = not_infered(Map.to_list(types))
    if(length(notinfer)>0) do
      IO.puts "Not infered:"
      IO.inspect notinfer
      IO.puts "Second pass:"
      types2 = infer_types(types,body)
      notinfer2 = not_infered(Map.to_list(types2))
      if (length(notinfer)==length(notinfer2)) do
        IO.inspect notinfer2
        #raise "Could not find types! Please use type annotations of the form: var x float, where x is an identifier"
        IO.inspect types
        IO.puts "Could not find types, choosing type float."
        map =for {var, type} <- types, into: %{} do if(type == :none)do {var, :float} else {var,type}  end end
        IO.inspect map
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
      {_,_}       -> not_infered(t)
    end
  end
  defmacro tinf(header, do: body) do
   {_fname, _, para} = header
   map = para
   |> Enum.map(fn({p, _, _}) -> p end)
   |> Map.new(fn x -> {x,:none} end)
   IO.inspect body
   nmap = infer_types(map,body)
   IO.inspect nmap
   :ok
  end

  ########################### adds return statement to functions that return an expression

  defp add_return(map,body) do
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
      {{:., info, [Access, :get]}, _, [arg1,arg2]} -> true
      {{:., _, [{_struct, _, nil}, _field]},_,[]} -> true
      {{:., _, [{:__aliases__, _, [_struct]}, _field]}, _, []} -> true
      {op, info, args} when op in [:+, :-, :/, :*] -> true
      {op, info, [arg1,arg2]} when op in [ :<=, :<, :>, :>=, :!=,:==] -> true
      {:!, info, [arg]} -> true
      {op, inf, args} when op in [ :&&, :||] -> true
      {var, info, nil} when is_atom(var) -> true
      #{fun, _, args} when is_list(args)-> true
      #{_fun, _, _noargs} ->
      float when  is_float(float) -> true
      int   when  is_integer(int) -> true
      string when is_binary(string)  -> true
      _                              -> false

   end
  end
#######################################################33

  def infer_types(map,body1) do

    body = add_return(map,body1)

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
             |> Map.put(array,:matrex)
             |> set_type_exp(:int,arg2)
          {:__shared__,_ , [{{:., _, [Access, :get]}, _, [arg1,arg2]}]} ->
             array = get_var arg1
             map
             |> Map.put(array,:matrex)
             |> set_type_exp(:int,arg2)
          # assignment
          {:=, _, [{{:., _, [Access, :get]}, _, [{array,_,_},acc_exp]}, exp]} ->
            map = map
            |> Map.put(array,:matrex)
            |> set_type_exp(:int, acc_exp)
            |> set_type_exp(:float,exp)
            map
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
                      infer_type_fun(map,exp) #  map
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
            inf_type = find_type_exp(map,arg)
            #IO.inspect "return #{type}"
            case inf_type do
              :none -> map
              _     -> current_type = Map.get(map,:return)
                       case current_type do
                            :none -> Map.put(map,:return,inf_type)
                            _     -> if inf_type == current_type do map else raise "Found two return types for function #{current_type} and #{inf_type}"end
                       end
            end

          {fun, _, args} when is_list(args)->
             type_fun = map[fun]
              if( type_fun == nil) do
                  Enum.reduce(args,map, fn v,acc -> infer_type_exp(acc,v) end)
              else
                  case type_fun do
                    :none ->      {map, infered_type}= infer_types_args(map,args,[])
                                  Map.put(map,fun, {:unit,infered_type})
                    {ret,type} -> {map, infered_type} = set_type_args(map,type,args,[])
                                  case ret do
                                    :none -> Map.put(map,fun, {:unit, infered_type})
                                    :unit -> Map.put(map,fun, {:unit, infered_type})
                                    t -> raise "Function #{fun} has return type #{t} as is being used in context :unit"
                                  end
                  end
              end
          number when is_integer(number) or is_float(number) -> raise "Error: number is a command"
          {str,_ ,_ } ->
            #IO.puts "yo"
            raise "Is #{str}  a command???"
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
defp set_type_args(map,[t1 | types], a1, newtype ) when is_tuple a1 do
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
defp set_type_args(map,[t1 | types], [a1,args], newtype ) do
  map=set_type_exp(map,t1,a1)
  set_type_args(map,types,args, newtype ++ [t1])
end
defp infer_types_args(map,[],type), do: {map,type}
defp infer_types_args(map,[h|tail],type) do
   t=find_type_exp(map,h)
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
       if(type != :float) do
         raise "Matrex  (#{inspect(arg1)}) (#{inspect(info)}) is being used in a context of type #{inspect type}"
       else
        map
        |> Map.put(get_var(arg1),:matrex)
        |> set_type_exp(:int,arg2)
       end
      {{:., _, [{_struct, _, nil}, _field]},_,[]} ->
        map
      {{:., _, [{:__aliases__, _, [_struct]}, _field]}, _, []} ->
        map
      {op, info, args} when op in [:+, :-, :/, :*] ->
          case args do
           [a1] ->
            if(type != :int && type != :float) do
              raise "Operaotr (-) (#{inspect info}) is being used in a context #{type}"
            end
            set_type_exp(map,type,a1)
           [a1,a2] ->
            if(type != :int && type != :float) do
              raise "Operaotr (#{inspect op}) (#{inspect info}) is being used in a context #{inspect type}"
            end
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
      {op, info, [arg1,arg2]} when op in [ :<=, :<, :>, :>=, :!=,:==] ->
        if(type != :int)  do
          raise "Operaotr (#{inspect op}) (#{inspect info}) is being used in a context #{inspect type}"
        end
        t1 = find_type_exp(map,arg1)
        t2 = find_type_exp(map, arg2)
        case t1 do
          :none ->
            map = set_type_exp(map,type,arg1)
            case t2 do
               :none -> set_type_exp(map,type,arg2)
               _     -> set_type_exp(map,t2,arg2)
            end
          _->
            map = set_type_exp(map,t1,arg1)
            case t2 do
              :none -> set_type_exp(map,type,arg2)
              _     -> set_type_exp(map,t2,arg2)
            end
        end
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
      {var, info, nil} when is_atom(var) ->
        if (Map.get(map,var)==nil) do
          raise "Error: variable #{inspect var} is used in expression before being declared"
        end
        if (Map.get(map,var) == :none) do
          Map.put(map,var,type)
        else
           if(Map.get(map,var) != type) do
             raise "Type error: #{inspect var} (#{inspect info}) is being used in a context of type #{type}"
           else
             map
           end
        end
      {fun, _, args} when is_list(args)->
         #IO.inspect args
         #raise "hell"
         type_fun = Map.get(map,fun)
         if( type_fun == nil) do
            Enum.reduce(args,map, fn v,acc -> infer_type_exp(acc,v) end)
          else
            case type_fun do
              :none ->      {map, infered_type}= infer_types_args(map,args,[])
                            IO.inspect {map, infered_type}
                            IO.inspect type
                            map = Map.put(map,fun, {type,infered_type})
                            map
              {ret,type_args} -> {map, infered_type} = set_type_args(map,type_args,args,[])
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
        {_fun, _, args} when is_list(args)->
          Enum.reduce(args,map, fn v,acc -> infer_type_exp(acc,v) end)
        _ -> map
       end
  end
  defp infer_type_exp(map,exp) do
    type = find_type_exp(map,exp)
    if (type != :none) do
      set_type_exp(map,type,exp)
    else
      map
    end
end

  defp find_type_exp(map,exp) do
      case exp do
         {{:., _, [Access, :get]}, _, [_arg1,_arg2]} ->
           :float
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
                           :none -> :none
                           _  -> raise "Incompatible operands (#{inspect info}: op (#{inspect op}) applyed to  type #{inspect t2}"
                          end
                :float -> :float
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

        {fun, _, _args} ->
            #IO.puts "aqui"
            #raise "hell"
            type_fun = map[fun]
            case type_fun do
                nil -> :none
                :none -> :none
                {ret,type} -> ret
            end

        float when  is_float(float) -> :float
        int   when  is_integer(int) -> :int
        string when is_binary(string)  -> :string
      end

    end


end
