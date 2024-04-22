require Hok
Hok.defmodule Teste do
 include PMap2
 defh soma() do
     return 1
  end
  def inc(x), do: x + 1
  def teste(), do: 1
end


IO.puts Teste.soma()
IO.puts Teste.inc(10)
IO.puts Teste.teste()
