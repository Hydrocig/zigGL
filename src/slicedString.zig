pub const slicedString = extern struct {
    data_ptr: [*]const u8,
    data_len: usize,
};

pub fn asSlice(self: slicedString) []const u8 {
    return self.data_ptr[0..self.data_len];
}
