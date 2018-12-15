import argparse
import time

def make_probability (in_string):
    try: 
        return Rational(float(in_string))
    except:
        return Rational(in_string)


def check_label (in_string, label):
    if in_string[0:len(label)+2] == "(" + label + " ":
        if in_string[-1] == ")":
            return True
    else:
        return False

def make_vector (in_string):
    return vector([int(e) for e in in_string[1:-1].split(",")])

def make_prob_tuple (in_string):
    ret = in_string.split(":")
    ret[0] = make_probability(ret[0])
    ret[1] = make_vector(ret[1])
    return ret

def make_prob_list (in_string):
    return [make_prob_tuple(e) for e in in_string.split(" :+: ")]

start_time = time.clock()

parser = argparse.ArgumentParser(description='Calculate exact runtime from file')
parser.add_argument('guardvec', type=str, help="The vector of the guard.")
parser.add_argument('guardval', type=str, help="The value of the guard.")
parser.add_argument('updates', type=str, help="The updates of the loop")
parser.add_argument('--dirterm', dest='directtermination', type=str, default=None, help="The direct termination update")
parser.add_argument('--prec', dest='precision', type=str, default=None, help="The precision for the calculations")
args = parser.parse_args()

# assign variables
guardvec = make_vector(args.guardvec)
guardval = int(args.guardval)
updates = make_prob_list(args.updates)

vec_length = len(guardvec)

# Optional arguments
direct_flag = False
prec_flag = False

# initialize empty direct termination
const_update = [Rational(0), vector(vec_length * [0])]
precision = 100

if not args.directtermination == None:
    direct_flag = True
    const_update = make_prob_tuple(args.directtermination)

if not args.precision == None:
    prec_flag = True
    precision = int(args.precision)

# transform program into a simple program
tmp_updates = [[e[0], e[1].dot_product(guardvec)] for e in updates]
scalar_updates = {}
for u in tmp_updates:
    if u[1] not in scalar_updates:
        scalar_updates[u[1]] = 0
    scalar_updates[u[1]] += u[0]
#m has to be positive, so if only negative values are inside the scalar_keys, m is set to 0
m = max(max(scalar_updates.keys()),0)
k = -min(scalar_updates.keys())

#Define all other probabilities to be zero
for ind in range(-k,1,m+1):
  if ind not in scalar_updates:
    scalar_updates[ind] = 0

scalar_const = (const_update[0], const_update[1].dot_product(guardvec) - guardval)

# check if direct termination actually terminates
if scalar_const[0] > 0 and scalar_const[1] > 0:
    print("ERROR: Direct Termination Vector does not terminate the program")
    quit()

# check if all the probabilities add up to 1
if not sum(scalar_updates.values()) + scalar_const[0] == 1:
    print("ERROR: probabilities do not add up to 1 (" + str(sum(scalar_updates.values()) + scalar_const[0]) + ")")
    quit()

drift = sum([i*j for i,j in scalar_updates.iteritems()])

# check if the runtime can be computed
if (scalar_const[0] == 0):
    if drift > 0:
        print("The given program is not AST. The expected runtime is infinite.")
        quit()
    elif drift == 0: 
      print("The given program is AST, but not PAST. The expected runtime is infinite.")
      quit()


char_coeffs = [(i+k, j-1) if i == 0 else (i+k,j) for i,j in scalar_updates.iteritems()]
x = polygen(ZZ)
monoms = [j * x^i for i,j in char_coeffs]
poly = sum(monoms)

if not drift == 0:
  c_val = -1/drift
  
if not scalar_const[0] == 0:
  c_val = 1/scalar_const[0]

  
# Precision Problem
roots = sage.rings.polynomial.complex_roots.complex_roots(poly, min_prec=precision)

CC = ComplexField(precision)
RR = RealField(precision)
roots = [(CC(root), mult) for root,mult in roots if RR(abs(root)) <= 1.]
roots = dict(roots)

filtered_roots = {}
for root in roots:
    if conjugate(root) not in filtered_roots:
        filtered_roots[root] = roots[root]

x = var('x')
r_monoms = []


for root in filtered_roots:
    if root.imag() != 0:
        r = abs(root)
        theta = arg(root)
        for u in range(filtered_roots[root]):
            r_monoms.append(r^x * cos(x*theta))
            r_monoms.append(r^x * sin(x*theta))
    else:
        for u in range(filtered_roots[root]):
            if root.real() == RR(1):
                # For some reason 1.000^x creates a div by zero error?!
                r_monoms.append(x^u)
            else:
                r_monoms.append(x^u*root.real()^x)

# Create set of linear equations

A = matrix([[monom(x=-i).real() for monom in r_monoms] for i in range(k)])
if scalar_const[0] == 0: 
  B = vector([c_val*(-i) for i in range(k)])
elif scalar_const > 0:
  B = vector([c_val for i in range(k)])
# We must have AX + B = 0, i.e. AX = -B has to be solved
solution = A.solve_right(-B)


# Construct the resulting formula
if scalar_const[0] == 0:
    r = c_val*x
else:
    r = c_val
for sol,monom in zip(solution, r_monoms):
    r += sol*monom
# substitute x by the original variables
v_vars = vector([var('x{id}'.format(id=i+1)) for i in range(vec_length)])
v = v_vars.dot_product(guardvec)-guardval
r = r.subs(x=v)

total_time = time.clock() - start_time

print("r{vars} = {res}".format(vars=v_vars,res=r))
print("time elapsed: {t}".format(t=total_time))
