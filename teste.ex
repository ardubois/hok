#require Hok

IO.inspect Enum.map([1,2,3,4], fn x -> x = x+x
                                       IO.inspect x
                                       x+x end)
