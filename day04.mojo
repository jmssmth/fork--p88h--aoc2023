from parser import *
from os.atomic import Atomic
from collections.vector import DynamicVector
from math import min, max
from memory import memset
from wrappers import minibench
from math.bit import ctpop


alias intptr = DTypePointer[DType.int32]

alias space = ord(' ')
alias zero = ord('0')

# Count the bits in a SIMD vector. Mojo doesn't expose the intrinsics that do this
# natively, shame. But we can reduce at least, so we just need 3 shifting steps.
fn bitcnt(m: SIMD[DType.uint8, 16]) -> Int:
    # odd / even bits
    alias s55 = SIMD[DType.uint8, 16](0x55)
    # two-bit mask
    alias s33 = SIMD[DType.uint8, 16](0x33)
    # four-bit mask
    alias s0F = SIMD[DType.uint8, 16](0x0F)
    # ref: Hacker's Delight or https://en.wikipedia.org/wiki/Hamming_weight
    var mm = m - ((m >> 1) & s55)
    mm = (mm & s33) + ((mm >> 2) & s33)
    mm = (mm + (mm >> 4)) & s0F
    return mm.reduce_add[1]().to_int()

# Count number of matches in a game
@always_inline
fn matches(t: Tuple[SIMD[DType.uint8, 16], SIMD[DType.uint8, 16]]) -> Int:
    let win: SIMD[DType.uint8, 16]
    let hand: SIMD[DType.uint8, 16]
    (win, hand) = t
    return ctpop(win & hand).reduce_add().to_int()

@always_inline
fn main() raises:
    let f = open("day04.txt", "r")
    let lines = make_parser['\n'](f.read())

    let count = lines.length()
    # Each game is represented as two 128bit numbers, stored as 16-byte SIMD vectors
    var games = DynamicVector[Tuple[SIMD[DType.uint8, 16], SIMD[DType.uint8, 16]]](count)
    # Counts number of instances of each ticket
    var draws = intptr.alloc(count)

    # Set a single bit in a 8-bit based bitfield
    @always_inline
    fn setbit(inout m: SIMD[DType.uint8, 16], v: Int):
        let f = v // 8
        let b = v % 8
        m[f] = m[f] | (1 << b)

    # Build a bitfield from a string containing integers
    fn bitfield(s: StringSlice) -> SIMD[DType.uint8, 16]:
        var ret = SIMD[DType.uint8, 16](0)
        var pos = 0
        let l = s.size
        var r = 0
        while pos < l:
            if s[pos] != space:
                r = r * 10 + s[pos].to_int() - zero
            elif r > 0:
                setbit(ret, r)
                r = 0
            pos += 1
        if r > 0:
            setbit(ret, r)
            r = 0
        return ret

    # Scan each game, split it into winning numbers and store as bit vectors
    @parameter
    fn parse() -> Int64:
        games.clear()
        for y in range(lines.length()):
            let s: StringSlice = lines.get(y)
            # achievement unlocked: https://github.com/modularml/mojo/issues/1367
            # the below doesn't work. We'll need to live with multiple spaces.
            # s = s.replace("  ", " ") + " "
            alias cOlon = ord(':')
            let start = s.find(cOlon)
            alias cPipe = ord('|')
            let sep = s.find(cPipe)
            let s1 = s[start + 2:sep]
            let s2 = s[sep + 2:]
            games.push_back((bitfield(s1), bitfield(s2)))
        return games.size

    # Take numbers of matches, exponentiate, sum up
    @parameter
    fn part1() -> Int64:
        var sum1 = 0
        for i in range(games.size):
            let w = 1 << matches(games[i])
            sum1 += w >> 1
        return sum1

    # Computes the ticket counts in draws table on the go
    @parameter
    fn part2() -> Int64:
        # Achievement #2 - memset with anything else than 0 doesn't work
        # https://github.com/modularml/mojo/issues/1368
        # We set ticket counts to zero then.
        memset(draws, 0, count)
        var sum2 : Int64 = 0
        for i in range(count):
            let cd = draws[i] + 1
            let x = matches(games[i])
            # Update next x draws
            for j in range(i + 1, min(count, i + x + 1)):
                draws[j] += cd
            sum2 += cd.to_int()
        return sum2

    # This part doesn't seem to benefit much from parallelization, so just run benchmarks.
    minibench[parse]("parse")
    minibench[part1]("part1")
    minibench[part2]("part2")

    # Ensure `lines` and `games` are still in use
    print(lines.length(), "rows")
    print(games.size, "games")
