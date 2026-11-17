import CoreGraphics

/// Spacing on a 4 pt grid. Use these instead of literal numbers.
public enum BifazSpacing {
    /// 4 pt
    public static let xxs: CGFloat = 4
    /// 8 pt
    public static let xs: CGFloat = 8
    /// 12 pt
    public static let s: CGFloat = 12
    /// 16 pt — default content inset.
    public static let m: CGFloat = 16
    /// 20 pt
    public static let l: CGFloat = 20
    /// 24 pt
    public static let xl: CGFloat = 24
    /// 32 pt
    public static let xxl: CGFloat = 32
    /// 48 pt
    public static let xxxl: CGFloat = 48

    /// Multiple of the 4 pt grid.
    public static func grid(_ steps: Int) -> CGFloat { CGFloat(steps) * 4 }
}

/// Corner radii (continuous corners).
public enum BifazRadius {
    /// 12 pt — chips, thumbnails, small controls.
    public static let small: CGFloat = 12
    /// 20 pt — cards and buttons.
    public static let medium: CGFloat = 20
    /// 28 pt — sheets and hero surfaces.
    public static let large: CGFloat = 28
}
