from setuptools import setup, find_packages
from pybind11.setup_helpers import Pybind11Extension, build_ext
from pybind11 import get_cmake_dir
import pybind11

ext_modules = [
    Pybind11Extension(
        "example_shared_py",
        [
            "src/python_bindings.cpp",
        ],
        include_dirs=[
            pybind11.get_include(),
            "../../target/include",
        ],
        libraries=["example_shared"],
        library_dirs=["../../target/release"],
        language='c++',
    ),
]

setup(
    name="example-shared-library",
    version="0.1.0",
    author="Monorepo Template",
    author_email="dev@example.com",
    description="Python bindings for the example shared library",
    long_description="",
    ext_modules=ext_modules,
    cmdclass={"build_ext": build_ext},
    zip_safe=False,
    python_requires=">=3.7",
    install_requires=[
        "pybind11>=2.10.0",
    ],
    packages=find_packages(),
)