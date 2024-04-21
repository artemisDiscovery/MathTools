

import Foundation 
import Dispatch

let computeQueue = DispatchQueue( label:"compute", attributes: .concurrent )
let blocksQueue = DispatchQueue( label:"blocks" )


struct Vector {
    var n:Int
    var coords:[Double]


    init(_ coords:[Double]) {
        n = coords.count 
        self.coords = coords 
    }

    func dist(_ other:Vector) -> Double {
        return sqrt( (0..<n) .map {pow(coords[$0] - other.coords[$0], 2)} .reduce(0.0) {$0 + $1} )
    }

    func diff(_ other:Vector) -> Vector {
        return Vector( (0..<n) .map { coords[$0] - other.coords[$0]} )
    }

    func add(_ other:Vector) -> Vector {
        return Vector( (0..<n) .map { coords[$0] + other.coords[$0]} )
    }

    func scale(_ by:Double) -> Vector {
        return Vector( (0..<n) .map { by * coords[$0]} )
    }

    func length() -> Double {
        return sqrt((0..<n) .map { coords[$0]*coords[$0] } .reduce(0.0) { $0 + $1 } )
    }

    func unit() -> Vector? {
        let len = self.length()
        if len == 0.0 {
            return nil
        }
        else {
            return Vector(self.coords).scale(1.0/len)
        }   
        
    }

    func cross( _ with:Vector) -> Vector {
        return Vector(  [coords[1]*with.coords[2] - with.coords[1]*coords[2],
                         coords[2]*with.coords[0] - with.coords[2]*coords[0],
                         coords[0]*with.coords[1] - with.coords[0]*coords[1]] )
    }

    func dot( _ with:Vector) -> Double {
        return (0..<n) .map { coords[$0]*with.coords[$0] } .reduce(0.0) {$0 + $1}
    }


}

extension Range {
    func contains(otherRange: Range) -> Bool {
        lowerBound <= otherRange.lowerBound && upperBound >= otherRange.upperBound
    }
}

enum MatrixError: Error {
    case shapeError
    case sizeError
    case invalidIndex
    case sliceError
    case domainError
    case typeError
    
}


struct Matrix<T:Numeric> {

    var shape:[Int]

    var strides:[Int]

    var count:Int

    var storage:Array<T> 

    init( _ inputshape:[Int], content:[T]? = nil  )  {
        shape = inputshape 
        count = 1

        for d in shape {
            count *= d
        }

        strides = [Int]() 

        for sidx in 0..<(shape.count - 1) {
            var str = 1
            for sjdx in (sidx+1)..<shape.count {
                str *= shape[sjdx]
            }
            strides.append(str)
        }

        // always have stride 1 for last dimension

        strides.append(1)

        var rep:Any?

        if T.self == Double.self {
            rep = 0.0
        }
        else if T.self == Int.self {
            rep = 0
        }
        else if T.self == Bool.self  {
            rep = false
        }
        

        if content == nil {
            storage = Array(repeating:(rep as! T), count:count)
        }
        else {
            storage = content!
        }
        
        

    }

    // with shape si,sj,sk,sl stride_i = (sj*sk*sl), stride_j = sk*sl, stride_k = sl 
    // so index of element [i,j,k] = i*(sj*sk) + j*sk + k

    func indicesFromIndex( _ index:Int ) throws -> [Int] {
        
        if index < 0 || index >= storage.count {
            throw MatrixError.invalidIndex
        }

        var indices = [Int]() 

        var remainder = index 

        for stride in strides {
            let idx = remainder / stride 
            indices.append(idx)
            remainder -= idx * stride 
        }

        return indices 
    }

    func indexFromIndices( _ indices:[Int] ) throws -> Int {
        
        if indices.count != shape.count {
            throw MatrixError.shapeError
        }

        var index = 0 

        for (sidx,idx) in indices.enumerated() {
            if idx < 0 || idx >= shape[sidx] {
                throw MatrixError.invalidIndex
            }

            index += strides[sidx] * idx
        }

        return index 
    }

    // for a range in each dimension, return index range and buffer


    func _slice_ranges( _ ranges:[Range<Int>] ) throws -> [T] {

        if ranges.count != shape.count {
            throw MatrixError.shapeError
        }

        for sidx in 0..<shape.count {
            if !(0..<shape[sidx]).contains(otherRange:ranges[sidx]) {
                throw MatrixError.invalidIndex
            }
        }
        var indices = ranges[0].map { $0 * strides[0] }

        for sidx in 1..<strides.count {
            // 
            var indices2 = [Int]()

            for idx in indices {
                for idx2 in ranges[sidx] {
                    indices2.append(idx + strides[sidx]*idx2)
                }
                indices = indices2
            } 

        }

        // coallesce into ranges

        // Start with spans, which are inclusive intervals

        var slicespans = [[Int]]() 

        var length = 0 

        var currentSpan = [indices[0],indices[0]] 

        for idx in indices[1..<indices.count] {
            
            if currentSpan[1] == idx - 1 {
                currentSpan[1] = idx
            }
            else {
                slicespans.append(currentSpan)
                length += currentSpan[1] - currentSpan[0] + 1
                currentSpan = [idx,idx]
            }
           
        }

        slicespans.append(currentSpan)
        length += currentSpan[1] - currentSpan[0] + 1

        let sliceranges = slicespans.map { $0[0]..<($0[1]+1) }

        var rep:Any?

        if T.self == Double.self {
            rep = 0.0
        }
        else if T.self == Int.self {
            rep = 0
        }
        else {
            rep = false
        }

        var buffer = Array(repeating:(rep as! T), count:length)

        var accum = 0 

        for range in sliceranges {
            _ = (range.enumerated()).map { buffer[accum + $0] = storage[$1] }
            accum += (range.upperBound - range.lowerBound)
        }

        return buffer

    }

    func slice( _ ranges:[Range<Int>] ) throws -> Matrix {
        var sliceshape = [Int]() 

        for range in ranges {
            sliceshape.append(range.upperBound - range.lowerBound )
        }

        //print("slice shape = \(sliceshape)")

        var theslice = Matrix<T>(sliceshape)

        var buffer:[T]?

        do {
            buffer = try _slice_ranges( ranges )
        }
        catch {
            throw MatrixError.sliceError
        }
        

        //print("buffer count = \(buffer.count)")
        //print("buffer : \(buffer)")

        // should work to just join values in order 

        //print("slice size = \(theslice.count)")
        //print("slice storage = \(theslice.storage)")

        _ = (0..<buffer!.count ).map { theslice.storage[$0] = buffer![$0] }

        return theslice

    }

    mutating func zeros() {
        var rep:Any?

        if T.self == Double.self {
            rep = 0.0
        }
        else if T.self == Int.self {
            rep = 0
        }
        else {
            rep = false
        }

        _ = (0..<count).map {  storage[$0] = (rep as! T) }
    }

    mutating func ones() {
        var rep:Any?

        if T.self == Double.self {
            rep = 1.0
        }
        else if T.self == Int.self {
            rep = 1
        }
        else {
            rep = true
        }
        _ = (0..<count).map { storage[$0] = (rep as! T) }
    }

    mutating func random(_ lower:Double = 0.0, _ upper:Double = 1.0 ) throws {
        if T.self != Double.self {
            throw MatrixError.typeError
        }
        _ = (0..<count).map { storage[$0] = Double.random(in: lower...upper ) as! T }
    }

    mutating func setValue(_ indices:[Int], _ value:T ) throws {
        if indices.count != shape.count {
            throw MatrixError.shapeError
        }

        var index = 0

        for (sidx,idx) in indices.enumerated() {
            if idx < 0 || idx >= shape[sidx] {
                throw MatrixError.invalidIndex
            }

            index += idx * strides[sidx]
            if index < 0 || index >= storage.count {
                throw MatrixError.sizeError
            }
        }

        storage[index] = value 
        
    }

    func getValue(_ indices:[Int] ) throws -> T {

        if indices.count != shape.count {
            throw MatrixError.shapeError
        }

        var index = 0

        for (sidx,idx) in indices.enumerated() {
            if idx < 0 || idx >= shape[sidx] {
                throw MatrixError.invalidIndex
            }
            
            index += idx * strides[sidx]

            if index < 0 || index >= storage.count {
                throw MatrixError.sizeError
            }
        }

        return storage[index]
        
    }

    func add( _ other:Matrix<T>) throws -> Matrix<T> {
        // require same shape
        if shape != other.shape {
            throw MatrixError.shapeError
        }

        if (T.self != Double.self) && (T.self != Int.self) {
            throw MatrixError.typeError
        }

        let sum = zip( storage, other.storage ) .map { $0 + $1 }

        return Matrix<T>(shape, content:sum )

    }

    func subtract( _ other:Matrix) throws -> Matrix<T> {
        // require same shape
        if shape != other.shape {
            throw MatrixError.shapeError
        }

        if (T.self != Double.self) && (T.self != Int.self) {
            throw MatrixError.typeError
        }

        let diff = zip( storage, other.storage ) .map { $0 - $1 }

        return Matrix<T>(shape, content:diff )

    }

    func multiply( _ other:Matrix) throws -> Matrix<T> {
        // require same shape
        if shape != other.shape {
            throw MatrixError.shapeError
        }

        if (T.self != Double.self) && (T.self != Int.self) {
            throw MatrixError.typeError
        }

        let diff = zip( storage, other.storage ) .map { $0 * $1 }

        return Matrix<T>(shape, content:diff )

    }

    func divide( _ other:Matrix) throws -> Matrix<T> {
        // require same shape
        if shape != other.shape {
            throw MatrixError.shapeError
        }

        if (T.self != Double.self) && (T.self != Int.self) {
            throw MatrixError.typeError
        }

        
        let ratio = zip( storage, other.storage ) .map { (($0 as! Double) / ($1 as! Double)) as! T }
        

        return Matrix<T>(shape, content:ratio )

    }

    func scale( _ scale:Double) throws -> Matrix<T> {
        // 

        if (T.self != Double.self) {
            throw MatrixError.typeError
        }

        let scaled_storage = storage .map { (scale * ($0 as! Double)) as! T }

        return Matrix<T>(shape, content:scaled_storage)

    }

    func power(_ pwr:Double) throws -> Matrix<T> {
        
        if (T.self != Double.self) {
            throw MatrixError.typeError
        }


        let mod_storage = storage .map { pow($0 as! Double, pwr) as! T }
               

        return Matrix<T>(shape, content:mod_storage)
    }

    func reciprocal() throws -> Matrix<T> {

        if (T.self != Double.self) {
            throw MatrixError.typeError
        }

        
        let mod_storage = storage .map { (1.0 / ($0 as! Double)) as! T }
        

        return Matrix<T>(shape, content:mod_storage)
    }
}





func addBlock(_ BLOCKS: inout [[Double]?], _ block:[Double], _ index:Int, _ offset:Int ) {

    BLOCKS[offset + index] = block

}

func addTupBlock(_ BLOCKS: inout [[[Int]]?], _ block:[[Int]], _ index:Int, _ offset:Int ) {

    BLOCKS[offset + index] = block

}

enum DistError : Error {
    case lastDimensionsDoNotMatch
}

func tupdist(_ A:[Double],_ B:[Double],_ aidx:Int,_ bidx:Int,_ DIM:Int) -> Double {
	return (pow(A[DIM*aidx] - B[bidx*DIM],2) + 
			pow(A[DIM*aidx + 1] - B[bidx*DIM + 1],2) + 
			pow(A[DIM*aidx + 2] - B[bidx*DIM + 2],2)).squareRoot()

}

func storageDistance( _ A:Matrix<Double>, _ B:Matrix<Double>, _ DIM:Int, _ index:Int, 
        _ Alimits:[[Int]], _ Blimits:[[Int]] ) -> ([Double],Int,[[Int]]) {

    let Atuplo = Alimits[index][0] 
    let Atuphi = Alimits[index][1]
    let Btuplo = Blimits[index][0] 
    let Btuphi = Blimits[index][1]

    // have break down this way - a more compact representation with three nested mappings is
    // 'too complicated' for the compiler to interpret !

    let dists = (Atuplo..<Atuphi) .flatMap { (atupidx) in 
        (Btuplo..<Btuphi) .map { tupdist(A.storage, B.storage, atupidx, $0, DIM ) }
    }

    let tups = (Atuplo..<Atuphi) .flatMap { (atupidx) in 
        (Btuplo..<Btuphi) .map { [atupidx, $0]  }
    }


    return (dists,index,tups)
}

func storageOP( _ A:Matrix<Double>, _ Alimits:[[Int]], _ index:Int, _ op:(Double)->Double) -> ([Double],Int) {

    let Alo = Alimits[index][0] 
    let Ahi = Alimits[index][1]

    let res = (Alo..<Ahi) .map { op(A.storage[$0]) }

    return (res,index)

}

func storageOP2( _ A:Matrix<Double>, _ B:Matrix<Double>, _ Alimits:[[Int]], _ index:Int, _ op:(Double,Double)->Double) -> ([Double],Int) {

    let Alo = Alimits[index][0] 
    let Ahi = Alimits[index][1]

    let res = (Alo..<Ahi) .map  { op(A.storage[$0],B.storage[$0]) }

    return (res,index)

}

func applyOP( _ A:Matrix<Double>, _ op: @escaping (Double)->Double, numthreads:Int=1) throws -> Matrix<Double> {


    let size = Int(floor(Double(A.storage.count)/Double(numthreads)))
    let nsections = Int(ceil(Double(A.storage.count)/Double(size)))

    var chunklimits = [[Int]]()

    

    for idx in 0..<nsections {
        let start = idx * size 
        var end = start
        if idx < nsections - 1 {
            end = start + size 
        }
        else {
            end = A.storage.count
        }
        chunklimits.append([start,end])
    }

    var BLOCKS = [[Double]?](repeating:nil, count:nsections) 

    let group = DispatchGroup() 

    for cidx in 0..<nsections {

                print("enter thread \(cidx)")
       
                group.enter()

                computeQueue.async {
                        let data = storageOP(A, chunklimits, cidx, op )

                        blocksQueue.sync {
                            addBlock( &BLOCKS, data.0, data.1, 0  )
                        }
                        group.leave()

                        print("exit thread \(data.1)")
                    }

            group.wait()
    } 

    var content = [Double]()

    for idx in 0..<nsections {
        content += BLOCKS[idx]!
    }

    return Matrix<Double>(A.shape, content:content)
}

func applyOP2( _ A:Matrix<Double>, _ B:Matrix<Double>, _ op: @escaping (Double,Double)->Double, numthreads:Int=1) throws 
            -> Matrix<Double> {

    if A.shape != B.shape {
        throw MatrixError.shapeError
    }

    let size = Int(floor(Double(A.storage.count)/Double(numthreads)))
    let nsections = Int(ceil(Double(A.storage.count)/Double(size)))

    var chunklimits = [[Int]]()

    for idx in 0..<nsections {
        let start = idx * size 
        var end = start
        if idx < nsections - 1 {
            end = start + size 
        }
        else {
            end = A.storage.count
        }
        chunklimits.append([start,end])
    }

    var BLOCKS = [[Double]?](repeating:nil, count:nsections) 

    let group = DispatchGroup() 

    for cidx in 0..<nsections {
       
                group.enter()

                computeQueue.async {
                        let data = storageOP2(A, B, chunklimits, cidx, op )

                        blocksQueue.sync {
                            addBlock( &BLOCKS, data.0, data.1, 0  )
                        }
                        group.leave()
                    }

            group.wait()
    } 

    var content = [Double]()

    for idx in 0..<nsections {
        content += BLOCKS[idx]!
    }

    return Matrix(A.shape, content:content)
}

func cdist( _ A:Matrix<Double>, _ B:Matrix<Double>, numthreads:Int=1 ) throws -> Matrix<Double> {
    
    // 

    let DIM = A.shape[A.shape.count-1]

    if B.shape[B.shape.count-1] != DIM {
        throw DistError.lastDimensionsDoNotMatch
    }

    // limits here correspond to DIM-tuples

    var Alimits = [[Int]]()
    var Blimits = [[Int]]()

    let reverse = A.count > B.count 


    let maxTupleCount = max((A.storage.count/DIM),(B.storage.count/DIM))

    let size = Int(floor(Double(maxTupleCount)/Double(numthreads)))
    let nsections = Int(ceil(Double(maxTupleCount)/Double(size)))
     
    var chunklimits = [[Int]]()
    var grpcount = -1

    for idx in 0..<nsections {
        let start = idx * size 
        var end = start
        if idx < nsections - 1 {
            end = start + size 
        }
        else {
            end = maxTupleCount
        }
        chunklimits.append([start,end])
    }
        // need each element of smaller list against chunks of larger list 
        
    if reverse {
        grpcount = B.storage.count/DIM
        for b in 0..<grpcount {
            for clim in chunklimits {
                Blimits.append([b,b+1])
                Alimits.append(clim)
            }
        }
    } else {
        grpcount = A.storage.count/DIM
        for a in 0..<grpcount  {
            for clim in chunklimits {
                Alimits.append([a,a+1])
                Blimits.append(clim)
            }
        }
    }
        

    var BLOCKS = [[Double]?](repeating:nil, count:grpcount*nsections) 
    
    // 

    for grp in 0..<grpcount {

            let Alim = Array(Alimits[(grp*nsections)..<((grp+1)*nsections)]) 
            let Blim = Array(Blimits[(grp*nsections)..<((grp+1)*nsections)])

            let group = DispatchGroup() 

            for idx in 0..<nsections {

                group.enter()

                computeQueue.async {
                        let data = storageDistance(A, B, DIM, idx, Alim, Blim )

                        blocksQueue.sync {
                            addBlock( &BLOCKS, data.0, data.1, grp*nsections  )
                        }
                        group.leave()
                    }

                

            }   
        
            group.wait()

    }

    // Assemble return array

    var DIST = [Double]()

    for idx in 0..<grpcount*nsections {
        DIST += BLOCKS[idx]!
    }

    // If reversed, 'A' index increase faster, need to rearrange
    // for aidx in 0..<|A| :
    //      append D[aidx + |A|*k], k in 0..< |B|
    if reverse {
        DIST = (0..<(A.count/DIM)) .flatMap { (aidx) in 
                (0..<(B.count/DIM)) .map { DIST[aidx + $0*(A.count/DIM)]} }
    }
    
    // output shape is combination of input shapes, not including the last dimension
    // (usually = 3)

    let outshape = Array(A.shape[0..<A.shape.count-1] + B.shape[0..<B.shape.count-1])
    return Matrix<Double>(outshape, content:DIST)
}



// the following is a testing version of the cdist function, returns a list of tuples corresponding to the 
// linear output storage. 
/*
func cdist_test( _ A:Matrix<Double>, _ B:Matrix<Double>, numthreads:Int=1, testing:Bool = false ) throws -> (Matrix, [[Int]]) {
    
    // 

    print("entering cdist")

    let DIM = A.shape[A.shape.count-1]

    if B.shape[B.shape.count-1] != DIM {
        throw DistError.lastDimensionsDoNotMatch
    }

    // limits here correspond to DIM-tuples

    var Alimits = [[Int]]()
    var Blimits = [[Int]]()

    let reverse = A.count > B.count 

    print("reverse : \(reverse)")

    let maxTupleCount = max((A.storage.count/DIM),(B.storage.count/DIM))

    let size = Int(floor(Double(maxTupleCount)/Double(numthreads)))
    let nsections = Int(ceil(Double(maxTupleCount)/Double(size)))
     
    var chunklimits = [[Int]]()
    var grpcount = -1

    for idx in 0..<nsections {
        let start = idx * size 
        var end = start
        if idx < nsections - 1 {
            end = start + size 
        }
        else {
            end = maxTupleCount
        }
        chunklimits.append([start,end])
    }
        // need each element of smaller list against chunks of larger list 
        
    if reverse {
        grpcount = B.storage.count/DIM
        for b in 0..<grpcount {
            for clim in chunklimits {
                Blimits.append([b,b+1])
                Alimits.append(clim)
            }
        }
    } else {
        grpcount = A.storage.count/DIM
        for a in 0..<grpcount  {
            for clim in chunklimits {
                Alimits.append([a,a+1])
                Blimits.append(clim)
            }
        }
    }
        
   

    print("limits A -- ")
    for lim in Alimits {
        print("\t\(lim)")
    }
    print("limits B -- ")
    for lim in Blimits {
        print("\t\(lim)")
    }

    var BLOCKS = [[Double]?](repeating:nil, count:grpcount*nsections) 
    var tupBLOCKS = [[[Int]]?](repeating:nil, count:grpcount*nsections) 
    
    // 

    for grp in 0..<grpcount {

            let Alim = Array(Alimits[(grp*nsections)..<((grp+1)*nsections)]) 
            let Blim = Array(Blimits[(grp*nsections)..<((grp+1)*nsections)])

            let group = DispatchGroup() 

            for idx in 0..<nsections {

                group.enter()

                print("start section \(idx)")

                computeQueue.async {
                        let data = storageDistance(A, B, DIM, idx, Alim, Blim )

                        blocksQueue.sync {
                            addBlock( &BLOCKS, data.0, data.1, grp*nsections  )
                            addTupBlock( &tupBLOCKS, data.2, data.1, grp*nsections  )
                        }
                        print("finished section \(idx)")
                        group.leave()
                    }

                

            }   
        
            group.wait()

    }

    // Assemble return array

    var DIST = [Double]()
    var TUPS = [[Int]]()

    for idx in 0..<grpcount*nsections {
        DIST += BLOCKS[idx]!
        TUPS += tupBLOCKS[idx]!
    }

    // If reversed, 'A' index increase faster, need to rearrange
    // for aidx in 0..<|A| :
    //      append D[aidx + |A|*k], k in 0..< |B|
    if reverse {
        DIST = (0..<(A.count/DIM)) .flatMap { (aidx) in 
                (0..<(B.count/DIM)) .map { DIST[aidx + $0*(A.count/DIM)]} }
        TUPS = (0..<(A.count/DIM)) .flatMap { (aidx) in 
                (0..<(B.count/DIM)) .map { TUPS[aidx + $0*(A.count/DIM)]} }
    }
    
    // output shape is combination of input shapes, not including the last dimension
    // (usually = 3)

    let outshape = Array(A.shape[0..<A.shape.count-1] + B.shape[0..<B.shape.count-1])
    return (Matrix(outshape, content:DIST), TUPS) 
}
*/