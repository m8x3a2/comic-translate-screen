"""Generates the tiny ONNX models used by ct_onnx tests.

    uv run --with onnx python tool/make_test_models.py

The outputs are committed (a few hundred bytes each), so this only needs to
run when the fixtures change.
"""

from pathlib import Path

import onnx
from onnx import TensorProto, helper

OUT = Path(__file__).resolve().parent.parent / "test" / "fixtures"


def save(model: onnx.ModelProto, name: str) -> None:
    model.ir_version = 8
    onnx.checker.check_model(model)
    OUT.mkdir(parents=True, exist_ok=True)
    onnx.save(model, OUT / name)
    print("wrote", OUT / name)


def add_model() -> onnx.ModelProto:
    """C = A + B, float32 [N, 3] with dynamic N."""
    a = helper.make_tensor_value_info("A", TensorProto.FLOAT, ["N", 3])
    b = helper.make_tensor_value_info("B", TensorProto.FLOAT, ["N", 3])
    c = helper.make_tensor_value_info("C", TensorProto.FLOAT, ["N", 3])
    graph = helper.make_graph([helper.make_node("Add", ["A", "B"], ["C"])], "add", [a, b], [c])
    return helper.make_model(graph, opset_imports=[helper.make_opsetid("", 13)])


def cast_model() -> onnx.ModelProto:
    """Y = float(X) * 0.5 and Z = X + 1 (int64), X: int64 [2, 2]; U = uint8 passthrough."""
    x = helper.make_tensor_value_info("X", TensorProto.INT64, [2, 2])
    u = helper.make_tensor_value_info("U", TensorProto.UINT8, [4])
    y = helper.make_tensor_value_info("Y", TensorProto.FLOAT, [2, 2])
    z = helper.make_tensor_value_info("Z", TensorProto.INT64, [2, 2])
    v = helper.make_tensor_value_info("V", TensorProto.UINT8, [4])
    half = helper.make_tensor("half", TensorProto.FLOAT, [], [0.5])
    one = helper.make_tensor("one", TensorProto.INT64, [], [1])
    nodes = [
        helper.make_node("Cast", ["X"], ["Xf"], to=TensorProto.FLOAT),
        helper.make_node("Mul", ["Xf", "half"], ["Y"]),
        helper.make_node("Add", ["X", "one"], ["Z"]),
        helper.make_node("Identity", ["U"], ["V"]),
    ]
    graph = helper.make_graph(nodes, "cast", [x, u], [y, z, v], initializer=[half, one])
    return helper.make_model(graph, opset_imports=[helper.make_opsetid("", 13)])


if __name__ == "__main__":
    save(add_model(), "add.onnx")
    save(cast_model(), "cast.onnx")
