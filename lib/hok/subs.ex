defmodule Subs do

############## Removing from kernel definition the arguments that are functions
def remove_args(map, ast) do
   case ast do
        {:defk, _info,[ {name, _i2,  args} ,block]} ->  {:defk, _info,[ {name, _i2, filter_args(map,args)} ,block]}
        _ -> raise "Recompiling kernel: unknown ast!"
   end

end

def filter_args(map,[{var,i, nil}| t]) do
  if map[var] ==  nil do
    [{var,i, nil}| filter_args(map,t)]
  else
    filter_args(t)
  end
end
def filter_args([]), do: []

def get_args(ast) do
  case ast do
       {:defk, _info,[ {_name, _i2,  args} ,_block]} ->  args
       _ -> raise "Recompiling kernel: unknown ast!"
  end

end

#######################
#########
######### Creates a map with the substitutions to be made: formal parameter => actual paramenter
########
#######################
def create_map_subs([funct |tt], [{fname,_,nil} | tfa], [func | taa], map) when is_list(funct) and is_function(func) do
  case Macro.escape(func) do
    {:&, [],[{:/, [], [{{:., [], [_module, func_name]}, [no_parens: true], []}, _nargs]}]} ->
        create_map_subs(tt,tfa,taa,Map.put(map,fname,func_name))
    _ -> raise "Problem with paramenter #{inspect func}"

  end
end
def create_map_subs([funct |tt], [{fname,_,nil} | tfa], [{:anon, lambda, _ref,_type} | taa], map) when is_list(funct) do
          create_map_subs(tt,tfa,taa,Map.put(map,fname,lambda))
end
def create_map_subs([_t |tt], [_fa | tfa], [_aa | taa], map)  do
  create_map_subs(tt,tfa,taa,map)
end
def create_map_subs([], [], [], map), do: map
def create_map_subs(_,_,_,_), do: raise "spawn: wrong number of parameters at kernel launch."

###################
################### substitute variables that represent functions by the actual function names
############   (substitutes formal parameters that are functions by their actual values)
########################

def subs(map,body) do

  #body = add_return(map,body)


  case body do
      {:__block__, _, _code} ->
        subs_block(map,body)
      {:do, {:__block__,pos, code}} ->
        {:do, subs_block(map, {:__block__, pos,code}) }
      {:do, exp} ->
        {:do, subs_command(map,exp)}
      {_,_,_} ->
        subs_command(map,body)
   end
end
defp subs_block(map,{:__block__, info, code}) do
  {:__block__, info,
      Enum.map(code,  fn com -> subs_command(map,com) end)
  }
end

defp subs_command(map,code) do
    case code do
        {:for,i,[param,[body]]} ->
          {:for,i,[param,[subs(map,body)]]}
        {:do_while, i, [[doblock]]} ->
          {:do_while, i, [[subs(map,doblock)]]}
        {:do_while_test, i, [exp]} ->
          {:do_while_test, i, [subs_exp(map,exp)]}
        {:while, i, [bexp,[body]]} ->
          {:while, i, [subs_exp(map,bexp),[subs(map,body)]]}
        # CRIAÇÃO DE NOVOS VETORES
        {{:., i1, [Access, :get]}, i2, [arg1,arg2]} ->
          {{:., i1, [Access, :get]}, i2, [subs_exp(map,arg1),subs_exp(map,arg2)]}
        {:__shared__, i1, [{{:., i2, [Access, :get]}, i3, [arg1,arg2]}]} ->
          {:__shared__,i1 , [{{:., i2, [Access, :get]}, i3, [subs_exp(map,arg1),subs_exp(map,arg2)]}]}

        # assignment
        {:=, i1, [{{:., i2, [Access, :get]}, i3, [{array,a1,a2},acc_exp]}, exp]} ->
          {:=, i1, [{{:., i2, [Access, :get]}, i3, [{array,a1,a2},subs_exp(map,acc_exp)]}, subs_exp(map,exp)]}
        {:=, i, [var, exp]} ->
          {:=, i, [var, subs_exp(map,exp)]}
        {:if, i, if_com} ->
          {:if, i, subs_if(map,if_com)}
        {:var, i1 , [{var,i2,[{:=, i3, [{type,ii,nil}, exp]}]}]} ->
          {:var, i1 , [{var,i2,[{:=, i3, [{type,ii,nil}, subs_exp(map,exp)]}]}]}
        {:var, i1 , [{var,i2,[{:=, i3, [type, exp]}]}]} ->
          {:var, i1 , [{var,i2,[{:=, i3, [type, subs_exp(map,exp)]}]}]}
        {:var, i1 , [{var,i2,[{type,i3,t}]}]} ->
          {:var, i1 , [{var,i2,[{type,i3,t}]}]}
        {:var, i1 , [{var,i2,[type]}]} ->
          {:var, i1 , [{var,i2,[type]}]}
        {:type, i1 , [{var,i2,[{type,i3,t}]}]} ->
          {:type, i1 , [{var,i2,[{type,i3,t}]}]}
        {:type, i1 , [{var,i2,[type]}]} ->
          {:type, i1 , [{var,i2,[type]}]}

        {:return,i,[arg]} ->
          {:return,i,[subs_exp(map,arg)]}

        {fun, info, args} when is_list(args)->
          new_name = map[fun]
          if (new_name == nil ) do
            {fun, info, Enum.map(args,fn(exp) -> subs_exp(map,exp) end)}
          else
            {new_name, info, Enum.map(args,fn(exp) -> subs_exp(map,exp) end)}
          end
        number when is_integer(number) or is_float(number) -> raise "Error: number is a command"
        {str,i1 ,a } -> {str,i1 ,a }

    end
end

defp subs_if(map,[bexp, [do: then]]) do
  [subs_exp(map,bexp), [do: subs(map,then)]]
end
defp subs_if(map,[bexp, [do: thenbranch, else: elsebranch]]) do
  [subs_exp(map,bexp), [do: subs(map,thenbranch), else: subs(map,elsebranch)]]
end


defp subs_exp(map,exp) do
    case exp do
      {{:., i1, [Access, :get]}, i2, [arg1,arg2]} ->
          {{:., i1, [Access, :get]}, i2, [arg1, subs_exp(map,arg2)]}
      {{:., i1, [{struct, i2, nil}, field]},i3,[]} ->
          {{:., i1, [{struct, i2, nil}, field]},i3,[]}
      {{:., i1, [{:__aliases__, i2, [struct]}, field]}, i3, []} ->
        {{:., i1, [{:__aliases__, i2, [struct]}, field]}, i3, []}
      {op,info, args} when op in [:+, :-, :/, :*] ->
        {op,info, Enum.map(args, fn e -> subs_exp(map,e) end)}
      {op, info, args} when op in [ :<=, :<, :>, :>=, :&&, :||, :!,:!=,:==] ->
        {op,info, Enum.map(args, fn e -> subs_exp(map,e) end)}
      {var,info, nil} when is_atom(var) ->
        {var, info, nil}
      {fun,info, args} ->
        new_name = map[fun]
        if (new_name == nil ) do
          {fun, info, Enum.map(args,fn(exp) -> subs_exp(map,exp) end)}
        else
          {new_name, info, Enum.map(args,fn(exp) -> subs_exp(map,exp) end)}
        end
      float when  is_float(float) -> float
      int   when  is_integer(int) -> int
      string when is_binary(string)  -> string
    end

  end


end
