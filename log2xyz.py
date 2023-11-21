import os
import re
import argparse

"Please modify the keyword for searching target energy value in line 43"

parser = argparse.ArgumentParser(description="Extract energy and structure from Gaussian log files.")
required = parser.add_argument_group("required arguments")
required.add_argument("-i","--input", type=str, help="input folder", required=True)
optional = parser.add_argument_group("optional arguments")
optional.add_argument("-o","--output", type=str, help="output .xyz", default="output.xyz")
args = parser.parse_args()

elements = ['H', 'He', 'Li', 'Be', 'B', 'C', 'N', 'O', 'F', 'Ne','Na', 'Mg', 'Al', 'Si', 'P', 'S', 'Cl', 'Ar', 'K','Ca']

def extract_structure_and_energy(log_file):
    with open(log_file, 'r') as file:
        log_content = file.readlines()

    # Check for normal termination
    if "Normal termination" not in log_content[-1]:
        return None, None

    # Search for "Input orientation:"
    structure_start = None
    for i, line in enumerate(log_content):
        if "Input orientation:" in line:
            structure_start = i + 5  # Start from the 5th line after "Input orientation:"
    
    if structure_start is None:
        return None, None

    # Extract structure coordinates
    structure_data = []
    for line in log_content[structure_start:]:
        if line.startswith(" -------"):
            break
        data = line.split()
        atom_number, atomic_number, _, x, y, z = map(float, data[:6])
        structure_data.append((atom_number, atomic_number, x, y, z))

    # Search for energy (EMP2)
    linenumberE = [ i for i,line in enumerate(log_content) if re.search("EUMP2 =",line)][-1]
    if linenumberE:
        final_energy = float(log_content[linenumberE].split()[-1].replace('D','e'))
    else:
        final_energy = None

    return structure_data, final_energy

def process_gjf_files(input_dir, output_filename):
    log_files = [f.replace('.gjf', '.log') for f in os.listdir(input_dir) if f.endswith('.gjf')]
    num_tot=len(log_files)
    num_normal = 0
    num_err = 0
    with open(output_filename, 'w') as output_file, open("resub.sh",'w') as ff:
        for log_file in log_files:
            log_file_path = os.path.join(input_dir, log_file)
            structure, energy = extract_structure_and_energy(log_file_path)

            if structure is not None and energy is not None:
                num_normal += 1
                # Write structure to output file
                output_file.write(f"{len(structure)}\n")
                output_file.write(f"{energy:.8f}\n")
                for data in structure:
                    output_file.write(f"{elements[int(data[1])-1]} {data[2]:14.6f} {data[3]:14.6f} {data[4]:14.6f}\n")
            else:
                num_err += 1
                ff.write(f"./rung16 log_file.replace('.log','gjf')  4 \n")
    print(f"The number of gjf files: {num_tot} \n")
    print(f"The number of normal termination log files: {num_normal} \n")
    print(f"The cartisian coordinates and energies are saved to the {output_filename} \n")
    print(f"The number of error termination log files: {int(num_err)} \n")
    if num_err != 0:
        print(f"You can restart calculation with resub.sh \n")
    else:
        os.remove("resub.sh")


if __name__ == "__main__":

    process_gjf_files(args.input, args.output)
