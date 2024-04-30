
require Hok

Hok.defmodule MM do
  defk mm(a,b,c,m,n,k) do
    row  = blockIdx.y * blockDim.y + threadIdx.y
    col = blockIdx.x * blockDim.x + threadIdx.x
    sum  = 0.0
    if(col < k && row < m) do
      for i in range(0,n,1) do
        sum = sum + a[row * n + i] * b[i * k + col]
      end
      c[row * k + col] = sum
    end

  end
defk map2xy2D_kernel(arr1,arr2, resp,size,f) do
  row  = blockIdx.y * blockDim.y + threadIdx.y
  col = blockIdx.x * blockDim.x + threadIdx.x

  if(col < size && row < size) do
    c[row * k + col] = f(arr1,arr2,row,col)
  end
end
defh map2xy2D(arr1,arr2,size,f) do
  block_size = 256
  grid_rows = trunc ((size + block_size - 1) / block_size)
  grid_cols = trunc ((size + block_size - 1) / block_size)
end
def comp22d(arr1,arr2,size1,size2) do
    result_gpu = Hok.new_gmatrex(1,size1*size2)
    array_gpu = Hok.new_gmatrex(array)

    MM.map2xy2D(arr1, arr2, result_gpu, size,func)

    r_gpu = Hok.get_gmatrex(result_gpu)
    r_gpu
end
end

Hok.include [MM]

[arg] = System.argv()

m = String.to_integer(arg)
n = m
k=m




mat = Matrex.fill(1,m*k,1)

f = fn _ -> Enum.random(1..100) end

mat1 = Matrex.apply(mat,f)
mat2 = Matrex.apply(mat,f)


block_size = 16
grid_rows = trunc ((m + block_size - 1) / block_size)
grid_cols = trunc ((k + block_size - 1) / block_size)


prev = System.monotonic_time()
ker=Hok.load(&MM.mm/6)
a=Hok.new_gmatrex(mat1)
b=Hok.new_gmatrex(mat2)
c=Hok.new_gmatrex(1,m*k)

Hok.spawn(ker,{grid_rows,grid_cols,1},{block_size,block_size,1},[a,b,c,m,n,k])
Hok.synchronize()

_result = Hok.get_gmatrex(c)

next = System.monotonic_time()
#IO.puts "time gpu #{System.convert_time_unit(next-prev,:native,:millisecond)}"
IO.puts "Hok\t#{m}\t#{System.convert_time_unit(next-prev,:native,:millisecond)} "

#IO.inspect result
#IO.puts GPU.Backend.gen_c_kernel('addVectors',4,[])
