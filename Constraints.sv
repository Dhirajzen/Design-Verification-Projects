//constraints
constraint c_addr{
    // addr inside {[8'h10 : 8'h7F]};
    !(addr inside {[8'h10 : 8'h7F]}); // for excluding the range
}

constraint c_addr{
    // addr % 4 == 0;
    addr [1:0] == 0; //alternative for byte alignment
}

constraint c_a_b{
    a > b;
    a inside{[10:50]};
    b inside{[0:20]};
}


//solve..before
constraint c_size_burst{
    size inside {[1,2,5,8]};
    burst_len % size == 0;
    solve size before burst_len; //solves size before the burst len
}

//dist
constraint c_opcode{
    opcode dist {2'b00 := 50, 2'b01 := 20, 2'b10 := 20, 2'b11 := 10};
}

//dynamic array
constraint c_arr{
    arr.size() inside {[8 : 16]};
    foreach(arr[i]){
        arr[i] != 0;
    }
    arr.sum() < 500;
}

// Generate dynamic array of exactly 300 elements. 
// Elements take values from {0,1,2,3,4}.
// Constraints: (1) Each value (0,1,2,3,4) appears at least 40 times, 
// (2) Value 0 can appear consecutively, 
// (3) Values 1,2,3,4 cannot appear consecutively (no adjacent repeats).

rand int arr[];
  
int values[5] = '{0, 1, 2, 3, 4};
  
constraint constraint_c {
    // Write constraints
    arr.size() == 25;
    foreach(arr[i]){
    arr[i] inside {0, 1, 2, 3, 4};
    if(i>0 && arr[i] != 0) arr[i] != arr[i-1];

    //if you want no consecutive zeros
    // if(i>0 && arr[i] == 0) arr[i-1] != arr[i];
    }
    foreach(values[k]){
        arr.sum() with (int'(item == values[k])) >= 5; 
    }

}

 
// Write constraint for array where parity of index matches parity of value. 
// Even indices (0,2,4,...) contain even values. 
// Odd indices (1,3,5,...) contain odd values. 
// Support arbitrary integer values (positive, negative, or zero).

rand int arr[];

constraint constraint_c {
    // Write constraints

    arr.size() == 15;
    foreach(arr[i]) {
    if(i % 2 == 0) arr[i] % 2 == 0;
    else arr[i] % 2 != 0;
    
    arr[i] inside {[0:10]};
    }
}




// Write constraint to randomize a 3-dimensional array (3×3×3 = 27 elements) 
// such that all elements are distinct. No two elements can have the same value. 
// Value domain must support at least 27 unique values.

  int arr[0:2][0:2][0:2];
  
  rand int flat[27];
    
  constraint constraint_c {
        // Write constraints
    foreach(flat[i]) flat[i] inside{[0:26]};
      
    unique{flat};
    
    
    }
  
  function void post_randomize();
    int i,j,k;
    int idx = 0;
    foreach(arr[i, j, k]) begin
      arr[i][j][k] = flat[idx++];
    $display("a[%0d][%0d][%0d] = flat[%0d] = %0d",
             i, j, k, idx, flat[idx]);
    end
      
  endfunction


//write a constraint to generate a number thats power of 4.

rand bit [8:0]num;

constraint constraint_c {
    // Write constraints
$countones(num) == 1;
//or
//$onehot(num);
foreach(num[i]) if(i % 2 != 0) num[i] == 0;


}


//index 5 should be 100 and others should be randomized.

rand int num[];

constraint constraint_c {
    // Write constraints
foreach(num[i]) num[i] inside {[0:100]};
num.size() > 6;
num.size() < 12;
num[5] == 100;


}

// Write constraint to generate a 4-bit number where the distribution of the 2 least significant bits (LSBs) is as follows:

rand bit [3:0]num;

constraint constraint_c {
    // Write constraints
num[1:0] dist { 2'b00:= 2, 2'b11:= 2, 2'b01:= 47, 2'b10 := 47 };
            

}

// Write uvm sv constraint to populate a queue with exactly "size" elements,
// where each element value is in range [0:size]. 
// The queue length and element values are coupled through the size variable.

rand int size;
rand int q[$];

constraint constraint_c {
size inside {[0:20]};   // optional bound; remove/change if needed

q.size() == size;

foreach (q[i]) {
    q[i] inside {[0:size]};
}
}


// Write uvm sv constraints to generate array where element 
// at index 5 is always fixed to value 100, while all other
//  elements are randomized within defined bounds. Array size must be at least 6 to have index 5.

rand int arr[];

constraint constraint_c {
arr.size() inside {[6:20]};   

arr[5] == 100;

foreach (arr[i]) {
    arr[i] inside {[0:100]};
}
}

//array-size constraint and decsending
constraint c_array{
    array.size inside {[10:16]};
    foreach(array[i])
        if(i>0) array[i] < array[i-1];
}

//dynamic array - random but unique
constraint c_darray{
    foreach(darray[i])
        if(i>0) darray[i] > darray[i-1];
}
function post_randomize;
    darray.shuffle();
endfunction

/*Given a 32 bit address field as a class member , write a constraint to generate a 
random value such that it always has 10 bits as 1 and no two bits next to each
other should be 1*/

constraint c_addr{
    $countones(addr) == 10;
    foreach(addr[i])
        if(addr[i] && i > 0) 
            addr[i] != addr[i-1];
}

////////////////////////////////////////////////////////////////////////////////////

// Generate M×N matrix where each element is {0,1} (binary). 
// Constraint: Sum of all matrix elements must be less than MAX_SUM. 
// Parameterize M, N, MAX_SUM. Avoid using .sum() reduction method.

class transaction#(int M, int N, int MAX_SUM);

    // Declare rand variable
  bit arr[M][N];
  
  rand bit [M*N]flat_a;
  
  constraint constraint_c {
    foreach(flat_a[i]) {
      flat_a[i] inside {1, 0};
    	}
    
      $countones(flat_a) == MAX_SUM;
    }
  
  function void post_randomize();
	
    int idx, i, j;
    
    foreach(arr[i, j]) begin
      arr[i][j] = flat_a[idx++];
    end
    
  endfunction

    function void display();
       //Display method
       $display("Array: %p", arr);
      $display("Flat Array: %b", flat_a);
    endfunction

    
    function new(string name="transaction");
       //Constructor
       
    endfunction
endclass


// Generate square matrix A and its 90° counterclockwise rotated version B. 
// Establish constraint relationship between A and B such that B is exact rotation of A. 

class transaction#(int M);

    // Declare rand variable
  rand int arr_B[M][M];
  int arr_A[M][M];
  
//   rand int [M*M]flat_a;
  
  constraint constraint_c {
    foreach(arr_B[i, j]) {
      arr_B[i][j] inside {[0:10]};
    	}
    
    }
  
  function void post_randomize();
	
    int i, j;
    
    foreach(arr_A[i, j]) begin
      arr_A[i][j] = arr_B[M-1-j][i];
    end
    
  endfunction

    function void display();
       // Display method
      $display("Array: %p", arr_B);
      $display("rot Array: %p", arr_A);
    endfunction

    
    function new(string name="transaction");
       // Constructor
       
    endfunction
endclass



// Write constraint to generate number whose binary representation 
// has all 1-bits grouped together in single contiguous run. 
// Pattern: some 0s, then all 1s together, then some 0s. 
// Run length can be 0 to W (width). 
// Support all-zeros and all-ones edge cases if specified.


  rand int run_length;
  rand int start;
  
  rand bit [0:W-1] num;
    
constraint constraint_c {
  start inside {[0:W-1]};
  solve start before run_length;

  run_length inside {[0:(W-start)]};

  foreach (num[i]) {
    if (i >= start && i < start + run_length)
      num[i] == 1;
    else
      num[i] == 0;
  }
}

/*Write SystemVerilog uvm constraints to generate 
two 3×3 matrices such that the minimum value in
matrix A differs from the minimum value in matrix B. 
Optionally enforce minimum uniqueness within each matrix.*/

class transaction;

  rand int arr_A[9];
  rand int arr_B[9];

  rand int minA;
  rand int minB;

  int arrA[3][3];
  int arrB[3][3];

  constraint constraint_c {
    minA inside {[0:100]};
    minB inside {[0:100]};

    minA != minB;

    foreach (arr_A[i]) {
      arr_A[i] inside {[0:100]};
      arr_A[i] >= minA;
    }

    foreach (arr_B[i]) {
      arr_B[i] inside {[0:100]};
      arr_B[i] >= minB;
    }

    // minimum appears exactly once
    arr_A.sum() with (int'(item == minA)) == 1;
    arr_B.sum() with (int'(item == minB)) == 1;
  }

  function void post_randomize();
    int idxA = 0;
    int idxB = 0;

    foreach (arrA[i,j])
      arrA[i][j] = arr_A[idxA++];

    foreach (arrB[i,j])
      arrB[i][j] = arr_B[idxB++];
  endfunction

  function void display();
    $display("minA = %0d", minA);
    $display("Array A: %p", arrA);
    $display("minB = %0d", minB);
    $display("Array B: %p", arrB);
    $display("-------------------------");
  endfunction

  function new(string name = "transaction");
  endfunction

endclass

