ast = quote do
   defmodule Teste do
   # import Hox
    def inc(x), do: x+1 end
    def soma(a,b) do
      a+b
    end
  end

IO.inspect ast
