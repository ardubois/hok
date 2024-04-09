defmodule Teste do
  import Hok
  deft soma float ~> float ~> float
  deff soma(a,b)do
    return a + b
  end
  deft apply [float ~> float ~> float] ~> float ~> float ~> unit
  defk apply(f,x,y) do
    f(x,y)
  end
end
