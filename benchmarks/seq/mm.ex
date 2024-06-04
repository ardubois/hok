

[arg] = System.argv()

m = String.to_integer(arg)
k=m




mat1 = Matrex.new(1, m*m, fn -> :rand.uniform(1000) end)
mat2 = Matrex.new(1, m*m, fn -> :rand.uniform(1000) end)

amat = Matrex.reshape(mat1,m,k)
bmat = Matrex.reshape(mat2,m,k)

prev = System.monotonic_time()
_cmat = Matrex.dot(amat,bmat)
next = System.monotonic_time()
#IO.puts "time cpu #{System.convert_time_unit(next-prev,:native,:millisecond)}"
IO.puts "Elixir\t#{m}\t#{System.convert_time_unit(next-prev,:native,:millisecond)} "

#rmat = Matrex.reshape(result,m,k)

#fmat = Matrex.subtract(cmat,rmat)


#IO.puts "this value must be zero: #{Matrex.sum(fmat)}"
