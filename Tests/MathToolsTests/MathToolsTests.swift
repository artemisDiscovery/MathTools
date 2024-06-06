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

        var matrix1 = Matrix<Double>(SHAPE)

        // check that accessors work OK 

        let storage = matrix1.getStorage()
        let shape = matrix1.getShape()
        //let strides = matrix1.getStrides()

        XCTAssertEqual(storage.count,SHAPE[0]*SHAPE[1]*SHAPE[2])
        XCTAssertEqual(shape,SHAPE)


        do {
            for idx in indices {
                let v = Double.random(in: 0.0...10.0)
                try matrix1.setValue(idx, v)
                values.append(v)
            }
            
        }
        catch {
            print("Exception on setValue for Double matrix")
        }
        do {
            for (nidx,idx) in indices.enumerated() {
                let v = try matrix1.getValue(idx)
                //print("compare index \(idx) :  \(v) =? \(values[nidx])")
                XCTAssertEqual(v,values[nidx])
            }
            
        }
        catch {
            print("Exception on getValue for Double matrix")
        }

        var matrix2 = Matrix<Int>(SHAPE)
        var intValues = [Int]()

        do {
            for idx in indices {
                let v = Double.random(in: 0.0...10.0)
                try matrix2.setValue(idx, Int(v))
                intValues.append(Int(v))
            }
            
        }
        catch {
            print("Exception on setValue for Int matrix")
        }
        do {
            for (nidx,idx) in indices.enumerated() {
                let v = try matrix2.getValue(idx)
                //print("compare index \(idx) :  \(v) =? \(values[nidx])")
                XCTAssertEqual(v,intValues[nidx])
            }
            
        }
        catch {
            print("Exception on getValue for Int matrix")
        }
        
        var MatDiag = Matrix<Double>([10,10])

        do {
            try MatDiag.setdiagonal(1.0)
        }
        catch {
            print("exception in setdiagonal()")
            return 
        }

        do {
            for i in 0..<10 {
                for j in 0..<10 {
                    let v = try MatDiag.getValue([i,j])
                    if i == j {
                        XCTAssert( v == 1.0 )
                    }
                    else {
                        XCTAssert( v == 0.0 )
                    }
                }
            }
        }
        catch {
            print( "unexpected exception in in getValue")
        }

        
    }

    func testMatrixRandom_and_IndexMethods() throws {

        let SHAPE = [10,20,3]

        var matrix = Matrix<Double>(SHAPE)

        do {
            try matrix.random()
        }
        catch {
            print("Exception in matrix.random()")
        }
        

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
        var matrix2 = Matrix<Double>(SHAPE)

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
 

    //print("shape A = \(shapeA) , shape B = \(shapeB)")

    // 

    var matA = Matrix<Double>(shapeA)
    var matB = Matrix<Double>(shapeB)

    do {
        try matA.random(0.0,10.0)
        try matB.random(0.0,10.0)
    }
    catch {
        print("exception in matrix.random()")
    }
    

    // manual distance computation 

    var manualDist = Matrix<Double>(comboShape)

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
    var distMat:Matrix<Double>?


    do {
        distMat = try cdist( matA, matB, numthreads:numthreads )
    
    }
    catch {
        print("exception running cdist")
    }
     
    XCTAssert( distMat != nil )

    //print("return matrix has shape \(distMat!.shape)")
   

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
 

    //print("shape A = \(shapeA) , shape B = \(shapeB)")

    // 

    var matA = Matrix<Double>(shapeA)
    var matB = Matrix<Double>(shapeB)

    do {
        try matA.random(0.0,10.0)
        try matB.random(0.0,10.0)
    }
    catch {
        print("exception in matrix.random()")
    }
    

    // manual distance computation 

    var manualDist = Matrix<Double>(comboShape)

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
    var distMat:Matrix<Double>?
    

    do {
        distMat = try cdist( matA, matB, numthreads:numthreads )
    
    }
    catch {
        print("exception running cdist")
    }
     
    XCTAssert( distMat != nil )

    //print("return matrix has shape \(distMat!.shape)")
   

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

 func testBasicMath() throws {

    let shape = [ 10, 5, 2]

    var matA = Matrix<Double>(shape)

    do {
        try matA.random(0.0,1.0)
    }
    catch {
        print("exception in matrix.random()")
    }
    

    

    var ONE = Matrix<Double>(shape)
    ONE.ones() 

    var matAplusONE:Matrix<Double>?
    var matAminusONE:Matrix<Double>?
    var matAplusCONSTONE:Matrix<Double>?
    var matAminusCONSTONE:Matrix<Double>?
    var matAdivideCONST3:Matrix<Double>?

    do {
        matAplusONE = try matA.add(ONE)
        matAplusCONSTONE = try matA.add(1.0)
    }
    catch {
        print("exception in add") 
    }

    do {
        matAminusONE = try matA.subtract(ONE)
        matAminusCONSTONE = try matA.subtract(1.0)
    }
    catch {
        print("exception in subtract") 
    }

    do { 
        
        for idx in 0..<10 {
            for jdx in 0..<5 {
                for kdx in 0..<2 {
                    let v0 = try matA.getValue([idx,jdx,kdx])
                    let v1 = try matAplusONE!.getValue([idx,jdx,kdx])
                    let v1c = try matAplusCONSTONE!.getValue([idx,jdx,kdx])
                    XCTAssert( abs((v0 + 1.0) - v1) < 0.00000001)
                    XCTAssert( abs((v0 + 1.0) - v1c) < 0.00000001)
                }
            }
        }
    }
    catch {
        print("unexpected exception in getValue, testBasicMath1") 
    }


   do { 
        
        for idx in 0..<10 {
            for jdx in 0..<5 {
                for kdx in 0..<2 {
                    let v0 = try matA.getValue([idx,jdx,kdx])
                    let v1 = try matAminusONE!.getValue([idx,jdx,kdx])
                    let v1c = try matAminusCONSTONE!.getValue([idx,jdx,kdx])
                    XCTAssert( abs((v0 - 1.0) - v1) < 0.00000001)
                    XCTAssert( abs((v0 - 1.0) - v1c) < 0.00000001)
                }
            }
        }
    }
    catch {
        print("unexpected exception in getValue, testBasicMath2") 
    }
    
    let scale = 3.5
    var matA_scaled:Matrix<Double>?

    do {
            matA_scaled = try matA.scale(scale)
    }
    catch {
        print("exception in scale") 
    }


    do { 
        
        for idx in 0..<10 {
            for jdx in 0..<5 {
                for kdx in 0..<2 {
                    let v0 = try matA.getValue([idx,jdx,kdx])
                    let v1 = try matA_scaled!.getValue([idx,jdx,kdx])
                    XCTAssert( abs(scale*v0 - v1) < 0.00000001)
                }
            }
        }
    }
    catch {
        print("unexpected exception in getValue, testBasicMath3") 
    }

    var matNonZero = Matrix<Double>(shape)

    do {
        try matNonZero.random(0.5, 1.0)
    }
    catch {
        print("exception in matrix.random()")
    }
    

    let power = 2.5

    var divided:Matrix<Double>?
    var topower:Matrix<Double>?
    
    var reciprocal:Matrix<Double>?
    var times:Matrix<Double>?

    do {
        divided = try matA.divide(matNonZero)
        topower = try matA.power(power)
        reciprocal = try matNonZero.reciprocal()
        times = try matA.multiply(matNonZero)
        matAdivideCONST3 = try matA.divide(3.0)
    }
    catch {
        print("exception in matrix math")
    }


    do { 
        
        for idx in 0..<10 {
            for jdx in 0..<5 {
                for kdx in 0..<2 {
                    let vA = try matA.getValue([idx,jdx,kdx])
                    let vnz = try matNonZero.getValue([idx,jdx,kdx])
                    let vd = try divided!.getValue([idx,jdx,kdx])
                    let vp = try topower!.getValue([idx,jdx,kdx])
                    let vt = try times!.getValue([idx,jdx,kdx])
                    let vr = try reciprocal!.getValue([idx,jdx,kdx])
                    let v3 = try matAdivideCONST3!.getValue([idx,jdx,kdx])
                    XCTAssert( abs((vA/vnz) - vd) < 0.00000001)
                    XCTAssert( abs(pow(vA,power) - vp) < 0.00000001)
                    XCTAssert( abs(vA*vnz - vt) < 0.00000001)
                    XCTAssert( abs(1.0/vnz - vr) < 0.00000001)
                    XCTAssert( abs(v3 - (vA)/3.0) < 0.00000001)
                }
            }
        }
    }
    catch {
        print("unexpected exception in getValue, testBasicMath4") 
    }
   }

    func testOps() throws {

        let shape = [ 10, 50, 200]

        var matA = Matrix<Double>(shape)

        do {
            try matA.random(0.0,3.14)
        }
        catch {
            print("exception in matrix.random()")
        }


        var cosA:Matrix<Double>?

        do {
            cosA = try applyOP(matA,  numthreads:10 ) { cos($0) }
        }
        catch {
            print("exception in applyOP (cosine)")
        }


        do { 
        
        for idx in 0..<10 {
            for jdx in 0..<50 {
                for kdx in 0..<200 {
                    let x = try matA.getValue([idx,jdx,kdx])
                    let v = try cosA!.getValue([idx,jdx,kdx])
                    XCTAssert( abs(v - cos(x))  < 0.00000001)
                }
            }
        }
    }
    catch {
        print("unexpected exception in getValue, testOps") 
    }
   }

    func testOps2() throws {

            let shape = [ 10, 50, 200]

            var matA = Matrix<Double>(shape)
            var matB = Matrix<Double>(shape)

            do {
                try matA.random(1.0,5.0)
                try matB.random(-5.0,-1.0)
            }
            catch {
                print("exception in matrix.random()")
            }


            var sum:Matrix<Double>?
            var difference:Matrix<Double>?
            var multiply:Matrix<Double>?
            var divide:Matrix<Double>?

            do {
                sum = try applyOP2(matA, matB, numthreads:10, +)
                difference = try applyOP2(matA, matB, numthreads:10, - )
                multiply = try applyOP2(matA, matB, numthreads:10, * )
                divide = try applyOP2(matA, matB, numthreads:10, / )
            }
            catch {
                print("exception in applyOP2")
            }


            do { 
            
            for idx in 0..<10 {
                for jdx in 0..<50 {
                    for kdx in 0..<200 {
                        let a = try matA.getValue([idx,jdx,kdx])
                        let b = try matB.getValue([idx,jdx,kdx])
                        let s = try sum!.getValue([idx,jdx,kdx])
                        let d = try difference!.getValue([idx,jdx,kdx])
                        let m = try multiply!.getValue([idx,jdx,kdx])
                        let v = try divide!.getValue([idx,jdx,kdx])
                        XCTAssert( abs((a+b) - s)  < 0.00000001)
                        XCTAssert( abs((a-b) - d)  < 0.00000001)
                        XCTAssert( abs((a*b) - m)  < 0.00000001)
                        XCTAssert( abs((a/b) - v)  < 0.00000001)
                    }
                }
            }
        }
        catch {
            print("unexpected exception in getValue, testOps2") 
        }
    }

    func testsum() throws {
        let storage = [ 0.0, 1.0, 2.0,  3.0, 4.0, 5.0,  6.0, 7.0, 8.0 ]

        let matA = Matrix<Double>( [3,3], content:storage )

        var sumA:Matrix<Double>?

        do {
            sumA = try matA.sum()
        }
        catch {
            print("matrix sum over last dimension throws exception")
        }

        XCTAssert( sumA!.getShape() == [3] )
        XCTAssert( sumA!.storage == [3.0, 12.0, 21.0 ])

    }

    func testTranspose() throws {

        let sizeA = 10
        let sizeB = 5

        var matA = Matrix<Double>([sizeA])
        var matB = Matrix<Double>([sizeB])

        do {
            try matA.random(0.5,1.0)
            try matB.random(0.5,1.0)
        }
        catch {
            print("unexpected exception in matrix.random")
        }

        var manualTransposeAdd = Matrix<Double>([sizeA,sizeB])
        var manualTransposeSub = Matrix<Double>([sizeA,sizeB])
        var manualTransposeMul = Matrix<Double>([sizeA,sizeB])
        var manualTransposeDiv = Matrix<Double>([sizeA,sizeB])

        do {
            for i in 0..<sizeA {
                for j in 0..<sizeB {
                    try manualTransposeAdd.setValue( [i,j], matA.getValue([i]) + matB.getValue([j]))
                    try manualTransposeSub.setValue( [i,j], matA.getValue([i]) - matB.getValue([j]))
                    try manualTransposeMul.setValue( [i,j], matA.getValue([i]) * matB.getValue([j]))
                    try manualTransposeDiv.setValue( [i,j], matA.getValue([i]) / matB.getValue([j]))
                }
            }
        }
        catch {
            print("unexpected exception in set/getValue")
        }

        var transposeAdd:Matrix<Double>?
        var transposeMul:Matrix<Double>?
        var transposeSub:Matrix<Double>?
        var transposeDiv:Matrix<Double>?

        do {
            transposeAdd = try matA.addTranspose(matB)
            transposeSub = try matA.subtractTranspose(matB)
            transposeMul = try matA.multiplyTranspose(matB)
            transposeDiv = try matA.divideTranspose(matB)
        }
        catch {
            print("exception in transpose math operation")
        }

        XCTAssert( transposeAdd!.shape == [sizeA,sizeB])
        XCTAssert( transposeSub!.shape == [sizeA,sizeB])
        XCTAssert( transposeMul!.shape == [sizeA,sizeB])
        XCTAssert( transposeDiv!.shape == [sizeA,sizeB])

        /*
        do {
            for i in 0..<sizeA {
                for j in 0..<sizeB {
                    let manadd = try manualTransposeAdd.getValue([i,j])
                    let transadd = try transposeAdd!.getValue([i,j])
                    print(" index \(i),\(j) manual add = \(manadd) trans add = \(transadd)")
                }
            }
        }
        catch {
            print("unexpected exception in set/getValue")
        }
        */

        XCTAssert(transposeAdd!.storage == manualTransposeAdd.storage )
        XCTAssert(transposeSub!.storage == manualTransposeSub.storage )
        XCTAssert(transposeMul!.storage == manualTransposeMul.storage )
        XCTAssert(transposeDiv!.storage == manualTransposeDiv.storage )


    }

    func testVector() throws {
        let X = Vector([1.0,0.0,0.0])
        let Y = Vector([0.0,1.0,0.0])

        let XplusY = X.add(Y)
        let XplusY2 = X + Y
        let XminusY = X.sub(Y)
        let XminusY2 = X - Y
        let scale = 2.0
        let Xtimes2 = X.scale(scale)
        let Xtimes2_2 = 2.0 * X
        let lenXtimes2 = Xtimes2.length()
        let Xunit = Xtimes2.unit()
        let distXY = X.dist(Y)
        let XcrossY = X.cross(Y)

        let dev_XplusY = abs(XplusY.coords[0] - 1.0) + abs(XplusY.coords[1] - 1.0) + abs(XplusY.coords[2])
        let dev_XminusY = abs(XminusY.coords[0] - 1.0) + abs(XminusY.coords[1] - (-1.0)) + abs(XminusY.coords[2])
        let dev_Xtimes2 = abs(Xtimes2.coords[0] - 2.0) + abs(Xtimes2.coords[1]) + abs(Xtimes2.coords[2])
        let dev_lenXtimes2 = abs(lenXtimes2 - 2.0)
        let dev_Xunit = abs(Xunit!.coords[0] - 1.0) + abs(Xunit!.coords[1]) + abs(Xunit!.coords[2])
        let dev_distXY = abs(sqrt(2.0) - distXY)
        let dev_XcrossY = abs(XcrossY.coords[0]) + abs(XcrossY.coords[1]) + abs(XcrossY.coords[2] - 1.0)

        XCTAssert( dev_XplusY  < 0.00000001)
        XCTAssert( dev_XminusY  < 0.00000001)
        XCTAssert( dev_Xtimes2  < 0.00000001)
        XCTAssert( dev_lenXtimes2  < 0.00000001)
        XCTAssert( dev_Xunit  < 0.00000001)
        XCTAssert( dev_distXY  < 0.00000001)
        XCTAssert( dev_XcrossY  < 0.00000001)

        XCTAssert( XplusY == XplusY2 )
        XCTAssert( XminusY == XminusY2 )
        XCTAssert( Xtimes2 == Xtimes2_2 )


    }

    func testIndicesInOrder() throws {
        let shape = [ 10, 50, 25]
        let matA = Matrix<Double>(shape)

        var refIndices = [[Int]]() 

        do {
            for idx in 0..<matA.count {
                let indice = try matA.indicesFromIndex(idx)
                refIndices.append(indice)
            }
        }
        catch {
            print("unexpected error in indicesFromIndex")
            return 
        }
        

        let indices = matA.indicesInOrder()

        for (indice,refindice) in zip(indices,refIndices) {
            //print("\(indice) : \(refindice)")
            XCTAssert(indice == refindice)
        }
    }

    func testMask() throws {
        let shape = [ 10, 50, 25]
        var matA = Matrix<Double>(shape)
        var matI = Matrix<Int>(shape)
        var matJ = Matrix<Int>(shape)
        var maskIJ:Mask?

        do {
            try matA.random(0.0, 1.0)
            try matI.random(0.0, 10.0)
            try matJ.random(0.0, 10.0)
            maskIJ = try Mask.compare(matI, matJ) { $0 < $1 }

        }
        catch {
            print("unexpected error in matrix.random() of compare two")
            return
        }

        let mask = Mask.compare(matA) {$0 < 0.5}
        let maskI = Mask.compare(matI) {$0 < 5}

        var trueIndices = [[Int]]()
        var falseIndices = [[Int]]()
        var trueValues = [Double]()

        var maskNonZero:[[Int]]?
        var maskTrue:[[Int]]?
        var maskTrueValues:[Double]?

        do {

            for i in 0..<10 {
                for j in 0..<50 {
                    for k in 0..<25 {
                        let v = try matA.getValue([i,j,k])
                        let vI = try matI.getValue([i,j,k])
                        let vJ = try matJ.getValue([i,j,k])
                        let b = try mask.getValue([i,j,k])
                        if b {
                            trueIndices.append([i,j,k])
                            trueValues.append(v)
                        }
                        else {
                            falseIndices.append([i,j,k])
                        }
                        let bI = try maskI.getValue([i,j,k])
                        let bIJ = try maskIJ!.getValue([i,j,k])
                        
                        //print("indices = \(i),\(j),\(k), val = \(v), mask = \(b)")
                        XCTAssert( b == (v < 0.5))
                        XCTAssert( bI == (vI < 5))
                        XCTAssert( bIJ == (vI < vJ))
                    }
                }
            }

            maskNonZero = mask.nonzero()
            let data = try matA.applyMask(mask)
            maskTrue = data.0
            maskTrueValues = data.1

        }
        catch {
            print("unexpected error in matrix.getValue()")
        }

        // check nonzero and applyMask output

        XCTAssert( trueIndices == maskNonZero! )
        XCTAssert( trueIndices == maskTrue!)
        XCTAssert( maskTrueValues! == trueValues )
    }

    func testSliceOp() throws {
        let storage = [ 0.0, 1.0, 2.0,  3.0, 4.0, 5.0,  6.0, 7.0, 8.0,
                        0.0, -1.0, -2.0,  -3.0, -4.0, -5.0,  -6.0, -7.0, -8.0 ]

        var matA = Matrix<Double>( [2,3,3], content:storage)

        // add to slice 0..<2, 0..<2, 1..<3

        let matB = Matrix<Double>( [2,2,2], content:[1.0, 2.0, 3.0, 4.0,   5.0, 6.0, 7.0, 8.0])

        // will add to matA indices 0,0,1  0,0,2  0,1,1, 0,1,2    1,0,1  1,0,2  1,1,1  1,1,2 

        // new values :
        //[ 0.0, 2.0, 4.0,  3.0, 7.0, 9.0,  6.0, 7.0, 8.0,
       //   0.0, 4.0, 4.0,  -3.0, 3.0, 3.0,  -6.0, -7.0, -8.0 ]

        do {
            try applyOP2_slice( matA, [0..<2, 0..<2, 1..<3], matB,  + )
        }
        catch {
            print("applyOP2_slice threw exception")
        }

        print("after sliceOP addition, A storage = \(matA.storage)")

    }

    func testSetValueForMask() throws {
        let storage = [ 0.0, 1.0, 2.0,  3.0, 4.0, 5.0,  6.0, 7.0, 8.0,
                        0.0, -1.0, -2.0,  -3.0, -4.0, -5.0,  -6.0, -7.0, -8.0 ]

        var matA = Matrix<Double>( [2,3,3], content:storage)

        let mask = Mask.compare( matA ) { $0 < 0.0 }

        do {
            try matA.setValueForMask(mask, 100.0 )
        }
        catch {
            print("setValueForMask threw exception")
        }

        print("after setValueForMask, A storage = \(matA.storage)")

    }

    func testMaskLogicals() throws {
        let storage = [ 0.0, 1.0, 2.0,  3.0, 4.0, 5.0,  6.0, 7.0, 8.0,
                        0.0, -1.0, -2.0,  -3.0, -4.0, -5.0,  -6.0, -7.0, -8.0 ]

        var matA = Matrix<Double>( [2,3,3], content:storage)

        let maskLE = Mask.compare( matA ) { $0 <= 0.0 }
        let maskGE = Mask.compare( matA ) { $0 >= 0.0 }

        var maskAND:Mask?
        var maskOR:Mask?
        var maskNOT:Mask?

        do {
            maskAND = try maskLE.logical_and(maskGE)
            maskOR = try maskLE.logical_or(maskGE)
            maskNOT = maskLE.logical_not()
        }
        catch {
            print("mask logical threw exception")
        }

        print("logical LE AND GE storage : \(maskAND!.storage)")
        print("logical LE OR GE storage : \(maskOR!.storage)")
        print("logical NOT LE storage : \(maskNOT!.storage)")

    }
}



