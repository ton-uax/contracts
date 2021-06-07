contract Safe {
   constructor() public {
        TvmCell code = tvm.code();
        optional(TvmCell) salt = tvm.codeSalt(code);
        require(salt.hasValue(), 101);
        (, address rootAddr) = salt.get().toSlice().decode(uint8, address);
        require(msg.sender == rootAddr, 102);
    }
}
