defmodule Teste do
  def new_gmatrex((%Nx.Tensor{data: data, type: type, shape: shape, names: name}) ) do
    %Nx.BinaryBackend{ state: array} = data
    {l,c} = shape
    #ref=create_nx_ref_nif(array,l,c)
    IO.inspect {:nx, type, shape, name ,  array}
  end
end


t = Nx.tensor([[1, 2, 3, 4]],type: {:f, 32})

#t = Matrex.new([[1,2,3,4]])

gm = Hok.new_gmatrex(t)

IO.inspect gm

mt = Hok.get_gmatrex(gm)

IO.inspect mt
