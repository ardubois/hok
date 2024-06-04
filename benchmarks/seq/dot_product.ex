defmodule DP do
  def map2([],[],_f), do: []
  def map2([a|t1],[b|t2], f), do: [f.(a,b) | map2(t1,t2,f)]
end

[arg] = System.argv()

n = String.to_integer(arg)


list1 = Enum.to_list(1..n)
list2 = Enum.to_list(1..n)

prev = System.monotonic_time()

_r = list1
   |> DP.map2(list2,fn (a,b) -> a * b end)
   |> Enum.reduce(0,fn (a,b) -> a + b end)

next = System.monotonic_time()
IO.puts "Elixir\t#{n}\t#{System.convert_time_unit(next-prev,:native,:millisecond)}"
