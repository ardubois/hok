require Hok

result = Hok.gpufor x <- 0..1000, mat1, y <- 0..1000, mat2 do v= x* x
                                                              result = v +y
                                                               result  end
