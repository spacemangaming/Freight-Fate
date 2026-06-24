import sys
import re
from pathlib import Path

def main():
    if len(sys.argv) < 2:
        print("Usage: python set_version.py <new_version>")
        sys.exit(1)
        
    new_ver = sys.argv[1]
    pyproject_path = Path(__file__).resolve().parent.parent / "pyproject.toml"
    
    if not pyproject_path.exists():
        print(f"Error: {pyproject_path} not found.")
        sys.exit(1)
        
    content = pyproject_path.read_text(encoding="utf-8")
    
    # Replace version under [project]
    new_content, count = re.subn(
        r'(?m)^(version\s*=\s*\")[^\"]*(\")',
        rf'\g<1>{new_ver}\g<2>',
        content
    )
    
    if count == 0:
        print("Error: Could not find version line in pyproject.toml.")
        sys.exit(1)
        
    pyproject_path.write_text(new_content, encoding="utf-8")
    print(f"Successfully updated version to {new_ver} in pyproject.toml.")

if __name__ == "__main__":
    main()
