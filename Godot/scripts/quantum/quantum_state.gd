extends RefCounted
## Tiny state-vector simulator for the cat's qubits.
##
## The state is a list of amplitudes, one per basis state (|00>, |01>, |10>, |11> for 2 qubits).
## Probability of a basis state = amplitude squared.
## Real numbers are enough for the gates used so far (H, X, Z, sign flips).
## Bit order matches Qiskit: in basis index i, qubit q is bit (i >> q) & 1,
## and labels are written with the highest qubit first ("10" = qubit 1 is 1, qubit 0 is 0).

var n_qubits: int
var amps := PackedFloat64Array()


func _init(qubits: int = 2) -> void:
	n_qubits = qubits
	reset(0)


func size() -> int:
	return 1 << n_qubits


## Put the cat in one definite basis state (a "solid" cat).
func reset(basis: int = 0) -> void:
	amps.resize(size())
	amps.fill(0.0)
	amps[basis] = 1.0


# ------------------------------------------------------------------ gates

## Hadamard on qubit q: |0> -> (|0> + |1>)/sqrt2, |1> -> (|0> - |1>)/sqrt2.
func h(q: int) -> void:
	var s := 1.0 / sqrt(2.0)
	var bit := 1 << q
	for i in size():
		if (i & bit) == 0:
			var a := amps[i]
			var b := amps[i | bit]
			amps[i] = (a + b) * s
			amps[i | bit] = (a - b) * s


func h_all() -> void:
	for q in n_qubits:
		h(q)


## X (NOT) on qubit q: swaps the amplitudes of each pair that differs only in that qubit.
func x(q: int) -> void:
	var bit := 1 << q
	for i in size():
		if (i & bit) == 0:
			var a := amps[i]
			amps[i] = amps[i | bit]
			amps[i | bit] = a


## Z on qubit q: flips the sign of every basis state where that qubit is 1.
func z(q: int) -> void:
	var bit := 1 << q
	for i in size():
		if (i & bit) != 0:
			amps[i] = -amps[i]


## Flip the sign of ONE basis state (a phase flip on one possibility, e.g. one ghost in a puddle).
func flip_sign(basis: int) -> void:
	amps[basis] = -amps[basis]


# ------------------------------------------------------------- measurement

func probability(i: int) -> float:
	return amps[i] * amps[i]


## Pick one basis state at random, weighted by the probabilities.
func sample(rng: RandomNumberGenerator) -> int:
	var r := rng.randf()
	var acc := 0.0
	var last := 0
	for i in size():
		var p := probability(i)
		if p > 0.0:
			last = i
			acc += p
			if r < acc:
				return i
	return last


## Full measurement: the state collapses to one basis state. Returns its index.
func measure_all(rng: RandomNumberGenerator) -> int:
	var k := sample(rng)
	reset(k)
	return k


## Partial measurement with a yes/no question: "is the cat one of `subset`?"
## Only collapses as much as needed: the answer's possibilities keep their ratios.
func measure_subset(subset: Array, rng: RandomNumberGenerator) -> bool:
	var inside := rng.randf() < subset_probability(subset)
	project_subset(subset, inside)
	return inside


func subset_probability(subset: Array) -> float:
	var p := 0.0
	for i in subset:
		p += probability(i)
	return p


## Keep only the possibilities that match the given answer, then renormalise.
func project_subset(subset: Array, inside: bool) -> void:
	for i in size():
		if (i in subset) != inside:
			amps[i] = 0.0
	normalize()


func normalize() -> void:
	var n := 0.0
	for a in amps:
		n += a * a
	n = sqrt(n)
	if n > 1e-12:
		for i in size():
			amps[i] /= n


## Index of the basis state if the cat is solid (one possibility at ~100%), else -1.
func basis_index() -> int:
	for i in size():
		if probability(i) > 0.999:
			return i
	return -1


# ----------------------------------------------------------------- display

func label(i: int) -> String:
	var s := ""
	for q in range(n_qubits - 1, -1, -1):
		s += "1" if ((i >> q) & 1) == 1 else "0"
	return s


## e.g. "|ψ⟩ = 0.50|00⟩ + 0.50|01⟩ − 0.50|10⟩ + 0.50|11⟩"
func ket_string() -> String:
	var s := ""
	for i in size():
		var a := amps[i]
		if absf(a) < 1e-6:
			continue
		var coef := "%.2f|%s⟩" % [absf(a), label(i)]
		if s == "":
			s = ("−" if a < 0 else "") + coef
		else:
			s += (" − " if a < 0 else " + ") + coef
	return "|ψ⟩ = " + s
