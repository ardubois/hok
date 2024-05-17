defmodule Teste do

  defmacro m(ast)do
    nast= Macro.escape ast
    quote do: IO.inspect (unquote nast)
  end
end

defmodule Teste2 do
require Teste

def dowork() do

  Teste.m(1+3*4)

end

end

Teste2.dowork
