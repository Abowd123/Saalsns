class_name ArithGen
## Procedural mental-math problems. Correct by construction:
## no negatives, divisions are exact, operands sized by level.

static func make(level: int, rng: RandomNumberGenerator) -> Dictionary:
	level = clampi(level, 1, 10)
	var ops := ["+"]
	if level >= 2:
		ops.append("-")
	if level >= 4:
		ops.append("×")
	if level >= 6:
		ops.append("÷")
	var op: String = ops[rng.randi_range(0, ops.size() - 1)]
	var hi := 10 + level * 8
	var a := 0
	var b := 0
	var ans := 0
	match op:
		"+":
			a = rng.randi_range(1, hi)
			b = rng.randi_range(1, hi)
			ans = a + b
		"-":
			a = rng.randi_range(2, hi)
			b = rng.randi_range(1, a - 1)
			ans = a - b
		"×":
			var m := 5 + level
			a = rng.randi_range(2, m)
			b = rng.randi_range(2, 9 + mini(level, 4))
			ans = a * b
		"÷":
			b = rng.randi_range(2, 9 + mini(level - 5, 3))
			ans = rng.randi_range(2, 5 + level)
			a = b * ans
	return {"text": "%d %s %d" % [a, op, b], "a": a, "b": b, "op": op, "answer": ans}


static func check(p: Dictionary) -> bool:
	match str(p["op"]):
		"+":
			return int(p["a"]) + int(p["b"]) == int(p["answer"])
		"-":
			return int(p["a"]) - int(p["b"]) == int(p["answer"]) and int(p["answer"]) >= 0
		"×":
			return int(p["a"]) * int(p["b"]) == int(p["answer"])
		"÷":
			return int(p["b"]) != 0 and int(p["a"]) % int(p["b"]) == 0 and int(p["a"]) / int(p["b"]) == int(p["answer"])
	return false
