import XCTest
@testable import MathTools

final class MathToolsTests: XCTestCase {
    
    func testMatrixSetGet() throws {
        // This is an example of a functional test case.
        // Use XCTAssert and related functions to verify your tests produce the correct
        // results.

        // random indices 

        let SHAPE = [100,20,3]

        var indices = (0..<100).map {  _ in [Int.random(in: 0...(SHAPE[0]-1)),Int.random(in: 0...(SHAPE[1]-1)),Int.random(in: 0...(SHAPE[2]-1))]}
        // watch out for repeated indices !!
        indices = Array(Set(indices)) 
        var values = [Double]() 

        var matrix1 = Matrix(SHAPE)

        do {
            for idx in indices {
                let v = Double.random(in: 0.0...10.0)
                try matrix1.setValue(idx, v)
                values.append(v)
            }
            
        }
        catch {
            print("Exception on setValue")
        }
        do {
            for (nidx,idx) in indices.enumerated() {
                let v = try matrix1.getValue(idx)
                //print("compare index \(idx) :  \(v) =? \(values[nidx])")
                XCTAssertEqual(v,values[nidx])
            }
            
        }
        catch {
            print("Exception on getValue")
        }
        
        
    }

    func testMatrixRandom_and_IndexMethods() throws {

        let SHAPE = [10,20,3]

        var matrix = Matrix(SHAPE)
        matrix.random()

        for idx in 0..<matrix.count {
            do {
                
                    let indices = try matrix.indicesFromIndex(idx)
                    let v = try matrix.getValue(indices)
                    //print("indicesFromIndex : idx, indices = \(idx) \(indices) : \(v) =? \(matrix.storage[idx])")
                    XCTAssertEqual(v,matrix.storage[idx])
               
            }
            catch {
                print("Exception in indicesFromIndex idx =  \(idx) ")
            }
         }

        do {
            for i in 0..<SHAPE[0] {
                for j in 0..<SHAPE[1] {
                    for k in 0..<SHAPE[2] {
                        let indices = [i,j,k]
                        let idx = try matrix.indexFromIndices(indices)
                        let v = try matrix.getValue(indices)
                        //print("indexFromIndices : idx, indices = \(idx) \(indices) : \(v) =? \(matrix.storage[idx])")
                        XCTAssertEqual(v,matrix.storage[idx])
                    }
                }
            }
        }
        catch {
            print("Exception in indexFromIndices")
        }
    }
    
    func testSliceMethod() throws {

        // match up slice indices to original indices 
        // 
        // set original to have content i,j,k -> i*10000 + j*100 + k
        let SHAPE = [10,20,3]
        var matrix2 = Matrix(SHAPE)

        //print("strides = \(matrix2.strides)")

        let ranges = [0..<5, 10..<20, 2..<3]
        var valuesInOrder = [Double]()

        for i in 0..<SHAPE[0] {
            for j in 0..<SHAPE[1] {
                for k in 0..<SHAPE[2] {
                    let indices = [i,j,k]
                    let v = 10000.0*Double(i) + 100.0*Double(j) + Double(k)
                    if ranges[0].contains(i) && ranges[1].contains(j) && ranges[2].contains(k) {
                        valuesInOrder.append(v)
                    } 
                    do {
                        try matrix2.setValue(indices,v)
                    }
                    catch {
                        print("unexpected exception")
                    }
                    
                }
            }
        }

        do {
            let slice = try matrix2.slice([0..<5, 10..<20, 2..<3])

            do {
                var count = 0
                for i in 0..<slice.shape[0] {
                    for j in 0..<slice.shape[1] {
                        for k in 0..<slice.shape[2] {
                            let indices = [i,j,k]
                            let v = try slice.getValue(indices)
                            XCTAssertEqual(v,valuesInOrder[count])
                            
                            //print("slice indices \(indices) -> \(v)  expect \(valuesInOrder[count])")
                            count += 1
                        }
                    }
                }
            }
            catch {
                print("exception in accessing slice")
            }
        }
        catch {
            print("exception in making slice")
        }

    }


   func testCdistMethod() throws {

    // test for lenght A < B
   
    let shapeA = [ 5, 2, 3]
    let shapeB = [10, 5, 2, 3]
    let comboShape = [ 5, 2, 10, 5, 2 ]
 

    print("shape A = \(shapeA) , shape B = \(shapeB)")

    // 

    var matA = Matrix(shapeA)
    var matB = Matrix(shapeB)

    matA.random(0.0,10.0)
    matB.random(0.0,10.0)

    // manual distance computation 

    var manualDist = Matrix(comboShape)

    do {
        for a0 in 0..<shapeA[0] {
            for a1 in 0..<shapeA[1] {
                for b0 in 0..<shapeB[0] {
                    for b1 in 0..<shapeB[1] {
                        for b2 in 0..<shapeB[2] {
                            var x = [ 0.0,0.0,0.0]
                            var y = [ 0.0,0.0,0.0]
                            for j in 0..<3 {
                                x[j] = try matA.getValue([a0,a1,j])
                                y[j] = try matB.getValue([b0,b1,b2,j])
                            }
                            let d = ((0..<3) .map { pow(x[$0] - y[$0] , 2)} . reduce( 0.0,{ $0 + $1})).squareRoot()
                            try manualDist.setValue([a0,a1,b0,b1,b2], d)
                        }
                    }
                }
            }
        }
    }
    catch {
        print("unexpected exception in setValue")
    }
   



    let numthreads = 10 
    var distMat:Matrix?


    do {
        distMat = try cdist( matA, matB, numthreads:numthreads )
    
    }
    catch {
        print("exception running cdist")
    }
     
    XCTAssert( distMat != nil )

    print("return matrix has shape \(distMat!.shape)")
   

    // check manual versus cdist output 
    
    do {
        for a0 in 0..<shapeA[0] {
            for a1 in 0..<shapeA[1] {
                for b0 in 0..<shapeB[0] {
                    for b1 in 0..<shapeB[1] {
                        for b2 in 0..<shapeB[2] {
                            let d1 = try distMat!.getValue([a0,a1,b0,b1,b2])
                            let d2 = try manualDist.getValue([a0,a1,b0,b1,b2])
                            //XCTAssertEqual(d1, d2)
                            //print("indices : \([a0,a1,b0,b1,b2]) : ref : \(d2) : cdist : \(d1)")
                            //let index1 = try distMat!.indexFromIndices([a0,a1,b0,b1,b2])
                            //let index2 = try manualDist.indexFromIndices([a0,a1,b0,b1,b2])
                            //let indexA = try matA.indexFromIndices([a0,a1,0])
                            //let indexB = try matB.indexFromIndices([b0,b1,b2,0])
                            //let tupA = indexA/3
                            //let tupB = indexB/3
                            //var tail = ""
                            //if abs(d1 - d2) < 0.000000001 {
                            //    tail = "******"
                            //}
                            //print("global index : \(index1) ; orig tup A : \(tupA) orig index B : \(tupB) TUPS : \(TUPS![index1]) \(tail)")
                            XCTAssert( abs(d1 - d2) < 0.00000001)
                        }
                    }
                }
            }
        }
    }
    catch {
       print("unexpected exception in set/getValue") 
    }
    

 }

 
   // a little hackish and lazy - going to ensure that the bigger argument comes first, so that I test the 'reverse' feature

   func testCdistMethod_reversed() throws {

    // test for length A > B
   
    let shapeA = [ 10, 5, 2, 3]
    let shapeB = [5, 2, 3]
    let comboShape = [ 10, 5, 2, 5, 2 ]
 

    print("shape A = \(shapeA) , shape B = \(shapeB)")

    // 

    var matA = Matrix(shapeA)
    var matB = Matrix(shapeB)

    matA.random(0.0,10.0)
    matB.random(0.0,10.0)

    // manual distance computation 

    var manualDist = Matrix(comboShape)

    do {
        for a0 in 0..<shapeA[0] {
            for a1 in 0..<shapeA[1] {
                for a2 in 0..<shapeA[2] {
                    for b0 in 0..<shapeB[0] {
                        for b1 in 0..<shapeB[1] {
                            var x = [ 0.0,0.0,0.0]
                            var y = [ 0.0,0.0,0.0]
                            for j in 0..<3 {
                                x[j] = try matA.getValue([a0,a1,a2,j])
                                y[j] = try matB.getValue([b0,b1,j])
                            }
                            let d = ((0..<3) .map { pow(x[$0] - y[$0] , 2)} . reduce( 0.0,{ $0 + $1})).squareRoot()
                            try manualDist.setValue([a0,a1,a2,b0,b1], d)
                        }
                    }
                }
            }
        }
    }
    catch {
        print("unexpected exception in setValue")
    }
   



    let numthreads = 10 
    var distMat:Matrix?
    

    do {
        distMat = try cdist( matA, matB, numthreads:numthreads )
    
    }
    catch {
        print("exception running cdist")
    }
     
    XCTAssert( distMat != nil )

    print("return matrix has shape \(distMat!.shape)")
   

    // check manual versus cdist output 
    
    do {
        for a0 in 0..<shapeA[0] {
            for a1 in 0..<shapeA[1] {
                for a2 in 0..<shapeA[2] {
                    for b0 in 0..<shapeB[0] {
                        for b1 in 0..<shapeB[1] {
                            let d1 = try distMat!.getValue([a0,a1,a2, b0,b1])
                            let d2 = try manualDist.getValue([a0,a1,a2,b0,b1])
                            //XCTAssertEqual(d1, d2)
                            //print("indices : \([a0,a1,b0,b1,b2]) : ref : \(d2) : cdist : \(d1)")
                            //let index1 = try distMat!.indexFromIndices([a0,a1,a2,b0,b1])
                            //let index2 = try manualDist.indexFromIndices([a0,a1,a2,b0,b1])
                            //let indexA = try matA.indexFromIndices([a0,a1,a2,0])
                            //let indexB = try matB.indexFromIndices([b0,b1,0])
                            //let tupA = indexA/3
                            //let tupB = indexB/3
                            //var tail = ""
                            //if abs(d1 - d2) < 0.000000001 {
                            //    tail = "******"
                            //}
                            //print("global index : \(index1) ; orig tup A : \(tupA) orig index B : \(tupB) TUPS : \(TUPS![index1]) \(tail)")
                            XCTAssert( abs(d1 - d2) < 0.00000001)
                        }
                    }
                }
            }
        }
    }
    catch {
       print("unexpected exception in set/getValue") 
    }
    

 }

}
