
require Hok

Hok.defmodule MM do

defk map2xy2D_kernel(arr1,arr2,par, resp,size,f) do
  row  = blockIdx.y * blockDim.y + threadIdx.y
  col = blockIdx.x * blockDim.x + threadIdx.x
  type par int
  type arr1 matrex
  type arr2 matrex

  if(col < size && row < size) do
    resp[row * size + col] = f(arr1,arr2,par,row,col)
  end
end
def map2xy2D1p(arr1,arr2,par,resp,size,f) do
  block_size = 16
  grid_rows = trunc ((size + block_size - 1) / block_size)
  grid_cols = trunc ((size + block_size - 1) / block_size)

  Hok.spawn(Hok.lt(&MM.map2xy2D_kernel/6),{grid_cols,grid_rows,1},{block_size,block_size,1},[arr1,arr2,par,resp,size,f])
end
def comp2xy2D1p(arr1,arr2,par,size1,size2,f) do

    result_gpu = Hok.new_gmatrex(1,size1*size2)
    arr1_gpu = Hok.new_gmatrex(arr1)
    arr2_gpu = Hok.new_gmatrex(arr2)

    MM.map2xy2D1p(arr1_gpu, arr2_gpu,par, result_gpu, size1,f)

    r_gpu = Hok.get_gmatrex(result_gpu)
    r_gpu
end
end

Hok.include [MM]

[arg] = System.argv()

m = String.to_integer(arg)

#m = 1000

#n = m
#k=m


#mat = Matrex.fill(1,m*k,1)
#f = fn _ -> Enum.random(1..100) end
#mat1 = Matrex.apply(mat,f)
#mat2 = Matrex.apply(mat,f)

#mat1 = Matrex.new([Enum.to_list(1..m*m)])
#mat2 = Matrex.new([Enum.to_list(1..m*m)])

mat1 = Matrex.new(1, m*m, fn -> :rand.uniform(1000) end)
mat2 = Matrex.new(1, m*m, fn -> :rand.uniform(1000) end)

prev = System.monotonic_time()



_result = Hok.gpufor x <- 0..m, y <- 0..m, mat1, mat2,m do
            sum = 0.0
            for i in range(0,m,1) do
                  sum = sum + mat1[x * m + i] * mat2[i * m + y]
            end
            sum
          end

next = System.monotonic_time()

IO.puts "Hok\t#{m}\t#{System.convert_time_unit(next-prev,:native,:millisecond)} "

#m1 = Matrex.reshape(mat1,m,m)
#m2 = Matrex.reshape(mat2,m,m)
#res_cpu = Matrex.dot(m1,m2)
#IO.inspect Matrex.sum(res_cpu)
#IO.inspect Matrex.sum(result)
