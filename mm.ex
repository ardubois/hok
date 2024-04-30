
require Hok

Hok.defmodule MM do
#  defk mm(a,b,c,m,n,k) do
#    row  = blockIdx.y * blockDim.y + threadIdx.y
#    col = blockIdx.x * blockDim.x + threadIdx.x
#    sum  = 0.0
#    if(col < k && row < m) do
#      for i in range(0,n,1) do
#        sum = sum + a[row * n + i] * b[i * k + col]
#      end
#      c[row * k + col] = sum
#    end
#  end
defk map2xy2D_kernel(arr1,arr2, resp,size,f) do
  row  = blockIdx.y * blockDim.y + threadIdx.y
  col = blockIdx.x * blockDim.x + threadIdx.x

  type arr1 matrex
  type arr2 matrex

  if(col < size && row < size) do
    c[row * size + col] = f(arr1,arr2,row,col)
  end
end
def map2xy2D(arr1,arr2,resp,size,f) do
  block_size = 256
  grid_rows = trunc ((size + block_size - 1) / block_size)
  grid_cols = trunc ((size + block_size - 1) / block_size)

  Hok.spawn(&MM.map2xy2D_kernel/5,{grid_rows,grid_cols,1},{block_size,block_size,1},[arr1,arr2,resp,size,f])
end
def comp2xy2d(arr1,arr2,size1,size2,f) do

    result_gpu = Hok.new_gmatrex(1,size1*size2)
    arr1_gpu = Hok.new_gmatrex(arr1)
    arr2_gpu = Hok.new_gmatrex(arr2)

    MM.map2xy2D(arr1_gpu, arr2_gpu, result_gpu, size1,f)

    r_gpu = Hok.get_gmatrex(result_gpu)
    r_gpu
end
end

Hok.include [MM]

#[arg] = System.argv()

#m = String.to_integer(arg)

m = 1000
#n = m
k=m





mat = Matrex.fill(1,m*k,1)

f = fn _ -> Enum.random(1..100) end

mat1 = Matrex.apply(mat,f)
mat2 = Matrex.apply(mat,f)



prev = System.monotonic_time()

result = MM.comp2xy2D(mat1,mat2,1000,1000, Hok.hok fn (mat1,mat2,x,y) ->
           10
          end)

#result = MM.comp2xy2D(mat1,mat2,1000,1000, Hok.hok fn (mat1,mat2,x,y) ->
#                                      sum = 0.0
#                                      for i in range(0,1000,1) do
#                                              sum = sum + mat1[x * 1000 + i] * mat2[i * 1000 + y]
#                                      end
#                                      sum end)

next = System.monotonic_time()
#IO.puts "time gpu #{System.convert_time_unit(next-prev,:native,:millisecond)}"
IO.puts "Hok\t#{m}\t#{System.convert_time_unit(next-prev,:native,:millisecond)} "

IO.inspect result
#IO.puts GPU.Backend.gen_c_kernel('addVectors',4,[])
