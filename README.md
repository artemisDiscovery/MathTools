## MathTools

MathTools will implement some basic math facilities (inspired by numpy) in Swift.

depends on Foundation and Dispatch

Current classes/methods :

    Matrix( shape:[Int,...Int], content:[Double]?) creates a matrix of arbitrary shape of Double values. 
                        The optional parameter 'content' provides initial values as a linear vector (must have count shape[0]*shape[1]...*shape[n]) 
                        Initial values are all 0.0 if content not provided

        .indicesFromIndex( Int )   Returns the indices [i,j,...n] for an element given its offset in linear storage
        
        .indexFromIndices( [Int,...,Int])  Returns the offset in linear storage given the indices [i,j,k,...n] of an element
        
        .slice([rng0, ..., rngn]) takes a slice given an open range for each dimension. All ranges must be specified (numpy syntax like ':' is not supported)
                                  Returns Matrix with same shape but slice of each dimension
        
        .zeros()  Set all elements to 0.0
        .ones()   Set all elements to 1.0
        .random( rng )  Sets all elements to psuedo-random numbers in CLOSED range <rng>

        .setValue( [Int,...,Int], Double)  Sets value for element with index [i,j,k,...n]
        .getValue( [Int,...,Int] )   Returns value for element with index [i,j,k,...n]


    cdist( A:Matrix, B:Matrix, numthreads=1)   Returns distance table, where we require that both A and B have final dimension DIM .
                                               If A has shape [i,j,k,DIM] and B has shape [l,m,n,o,DIM], output has shape [i,j,k,l,m,n,o], 
                                               with entries = sqrt( SUM(d in 0..<DIM) {(A[i,j,k,d] - B[l,m,n,o,d])**2} )

                                            Number of threads must be set explicitly, environment variables are not examined

 

        





