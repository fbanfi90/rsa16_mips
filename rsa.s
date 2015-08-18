.globl  rsa_init                            # generate the public and private keys
.globl  rsa_clear                           # clear the public and private keys
.globl  rsa_get_n                           # get modulo n (result in $v0)
.globl  rsa_get_e                           # get public exponent e (result in $v0)
.globl  rsa_decrypt                         # decrypt value (value in $a0, result in $v0)
.globl  rsa_encrypt                         # encrypt value (value in $a0, modulo in $a1, public exponent in $a2, result in $v0)

.data
.align  2                                   # align data on word boundary
rsa_n:  .space  4                           # the public modulo
rsa_e:  .space  4                           # the public key e
rsa_d:  .space  4                           # the private key d

.text
# generate the public and private keys
rsa_init:
        addi    $sp, $sp, -4                # make room for a word on the stack
        sw      $ra, 0($sp)                 # save return address on the stack
rsa_init_gen_p:
        li      $a0, 1                      # i.d. of pseudorandom number generator (any int)
        li      $a1, 0xff                   # upper bound of range of returned values
        li      $v0, 42                     # random int range syscall
        syscall                             # perform system call
        addiu   $a0, $a0, 3                 # make sure p is larger than 3
        ori     $a0, 1                      # make sure p is odd
        jal     is_prime                    # test p primality
        beqz    $v0, rsa_init_gen_p         # if p not prime repeat
        move    $t0, $a0                    # save p
rsa_init_gen_q:
        li      $a0, 1                      # i.d. of pseudorandom number generator (any int)
        li      $a1, 0xff                   # upper bound of range of returned values
        li      $v0, 42                     # random int range syscall
        syscall                             # perform system call
        addiu   $a0, $a0, 3                 # make sure q is larger than 3
        ori     $a0, 1                      # make sure q is odd
        jal     is_prime                    # test q primality
        beqz    $v0, rsa_init_gen_q         # if q not prime repeat
        move    $t1, $a0                    # save q
        mul     $a0, $t0, $t1               # calculate n = p * q
        sw      $a0, rsa_n                  # save n to memory
        li      $a0, 17                     # commonly used as public exponent (65537 when 32)
        sw      $a0, rsa_e                  # save e to memory
        addi    $t0, $t0, -1                # decrease p by 1
        addi    $t1, $t1, -1                # decrease q by 1
        mul     $a1, $t0, $t1               # calculate phi(n) = (p - 1) * (q - 1)
        move    $t1, $a1                    # temporarily save phi(n)
        jal     rsa_ext_euclid              # calculate inverse multiplicative d of e
        bgtz    $v0, rsa_init_x_ok          # check whether x > 0
        addu    $v0, $v0, $t1               # x := x + t
rsa_init_x_ok:
        sw      $v0, rsa_d                  # save d to memory
        lw      $ra, 0($sp)                 # reset return address
        addi    $sp, $sp, 4                 # clear the stack
        jr      $ra                         # jump to return address

# clear the public and private keys
rsa_clear:
        li      $t0, 0                      # clear keys setting them to zero
        sw      $t0, rsa_n                  # clear n
        sw      $t0, rsa_e                  # clear e
        sw      $t0, rsa_d                  # clear d
        jr      $ra                         # jump to return address

# get modulo n (result in $v0)
rsa_get_n:
        lw      $v0, rsa_n                  # return n
        jr      $ra                         # jump to return address

# get public exponent e (result in $v0)
rsa_get_e:
        lw      $v0, rsa_e                  # return e
        jr      $ra                         # jump to return address

# decrypt value (value in $a0, result in $v0)
rsa_decrypt:
        addi    $sp, $sp, -4                # make room for a word on the stack
        sw      $ra, 0($sp)                 # save return address on the stack
        lw      $a1, rsa_n                  # load argument modulo
        lw      $a2, rsa_d                  # load argument private exponent
        jal     rsa_mod_exp                 # result = c ^ d mod n
        lw      $ra, 0($sp)                 # reset return address
        addi    $sp, $sp, 4                 # clear the stack
        jr      $ra                         # jump to return address

# encrypt value (value in $a0, modulo in $a1, public exponent in $a2, result in $v0)
rsa_encrypt:
        addi    $sp, $sp, -4                # make room for a word on the stack
        sw      $ra, 0($sp)                 # save return address on the stack
        jal     rsa_mod_exp                 # result = m ^ e mod n
        lw      $ra, 0($sp)                 # reset return address
        addi    $sp, $sp, 4                 # clear the stack
        jr      $ra                         # jump to return address

# modular exponentiation (b in $a0, e in $a2, m in $a1)
rsa_mod_exp:
        li      $v0, 1                      # set counter c to 1
rsa_mod_exp_loop:
        blez    $a2, rsa_mod_exp_end        # if e <= 0 return c
        andi    $t0, $a2, 1                 # e & 1
        beqz    $t0, rsa_mod_exp_skip       # if e & 1 = 0 skip
        mul     $v0, $a0, $v0               # c = b * c
        divu    $v0, $a1                    # get remainder in hi register
        mfhi    $v0                         # c = (b * c) mod m
rsa_mod_exp_skip:
        srl     $a2, $a2, 1                 # e = e >> 1
        mul     $a0, $a0, $a0               # b = b * b
        divu    $a0, $a1                    # get remainder in hi register
        mfhi    $a0                         # b = (b * b) mod m
        j       rsa_mod_exp_loop            # repeat
rsa_mod_exp_end:
        jr      $ra                         # jump to return address

# extended euclidean algorithm
rsa_ext_euclid:
        addi    $sp, $sp, -8                # make room for 2 words on the stack
        sw      $ra, 4($sp)                 # save return address on the stack
        sw      $s0, 0($sp)                 # save $s0 on the stack
        div     $a1, $a0                    # n / m in lo, n % m in hi
        mfhi    $t0                         # save n % m
        beqz    $t0, rsa_ext_euclid_return  # if n % m = 0 return (1, 0)
        mflo    $s0                         # save n / m (preserved after recursive call)
        move    $a1, $a0                    # n = m
        move    $a0, $t0                    # m = n mod m
        jal     rsa_ext_euclid              # recursive call and get (x', y')
        mul     $t0, $v0, $s0               # x' * (n / m) in $t0
        sub     $t0, $v1, $t0               # y' - x' * (n / m) in $t0
        move    $v1, $v0                    # y = x'
        move    $v0, $t0                    # x = y' - x' * (n / m)
        j       rsa_ext_euclid_end          # return (x, y)
rsa_ext_euclid_return:
        li      $v0, 1                      # x = 1
        li      $v1, 0                      # y = 0
rsa_ext_euclid_end:
        lw      $s0, 0($sp)                 # reset $s0
        lw      $ra, 4($sp)                 # reset return address
        addi    $sp, $sp, 8                 # clear the stack
        jr      $ra                         # jump to return address
        
# primality test for n odd and larger than 3
is_prime:
        mtc1    $a0, $f0                    # move n to fpu
        cvt.s.w $f0, $f0                    # convert word in $f0 to single
        sqrt.s  $f0, $f0                    # calculate sqrt of n
        cvt.w.s $f0, $f0                    # convert single in $f0 to word
        mfc1    $t2, $f0                    # move sqrt(n) from fpu to counter
        or      $t2, 1                      # make sure counter is odd
rsa_is_prime_loop:
        divu    $a0, $t2                    # divide n by counter and save remainder to register hi
        mfhi    $t3                         # save remainder
        beqz    $t3, rsa_is_prime_false     # if remainder is zero return false
        addi    $t2, $t2, -2                # decrease counter by 2
        bge     $t2, 3, rsa_is_prime_loop   # repeat until counter is 3
        li      $v0, 1                      # return false
        jr      $ra                         # jump to return address
rsa_is_prime_false:
        li      $v0, 0                      # return false
        jr      $ra                         # jump to return address
