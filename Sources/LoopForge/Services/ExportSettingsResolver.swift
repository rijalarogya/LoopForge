import Foundation

struct ExportSettingsValidationError: LocalizedError, Equatable {
    let issues: [String]

    var errorDescription: String? {
        issues.joined(separator: "\n")
    }
}

struct ExportSettingsResolver {
    func resolve(
        selection: ExportSettingsSelection,
        sourceWidth: Int?,
        sourceHeight: Int?,
        sourceFPS: Double?
    ) throws -> ResolvedExportSettings {
        var issues: [String] = []

        let dimensions: (width: Int, height: Int)?
        switch selection.resolution {
        case .source:
            if let sourceWidth, let sourceHeight {
                dimensions = (sourceWidth, sourceHeight)
            } else {
                dimensions = nil
                issues.append("The source video resolution could not be determined.")
            }
        case .custom:
            let widthText = selection.customWidthText.trimmingCharacters(in: .whitespacesAndNewlines)
            let heightText = selection.customHeightText.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !widthText.isEmpty, !heightText.isEmpty,
                  let width = Int(widthText), let height = Int(heightText) else {
                throw ExportSettingsValidationError(
                    issues: ["Custom export width and height must both be whole numbers."]
                )
            }
            dimensions = (width, height)
        default:
            dimensions = selection.resolution.dimensions
        }

        if let dimensions {
            validateDimension(dimensions.width, name: "Export width", issues: &issues)
            validateDimension(dimensions.height, name: "Export height", issues: &issues)
        }

        let fps: Double?
        if let selectedFPS = selection.frameRate.value {
            fps = selectedFPS
        } else if let sourceFPS, sourceFPS.isFinite, sourceFPS >= 1, sourceFPS <= 120 {
            fps = sourceFPS
        } else {
            fps = nil
            issues.append("The source video frame rate could not be determined.")
        }

        guard issues.isEmpty, let dimensions, let fps else {
            throw ExportSettingsValidationError(issues: issues)
        }

        let isUpscaling: Bool
        if let sourceWidth, let sourceHeight {
            isUpscaling = dimensions.width > sourceWidth || dimensions.height > sourceHeight
        } else {
            isUpscaling = false
        }

        return ResolvedExportSettings(
            width: dimensions.width,
            height: dimensions.height,
            fps: fps,
            quality: selection.quality,
            encodingSpeed: selection.encodingSpeed,
            audioBitrate: selection.audioBitrate,
            isUpscaling: isUpscaling
        )
    }

    private func validateDimension(_ value: Int, name: String, issues: inout [String]) {
        if value < 16 || value > 16_384 {
            issues.append("\(name) must be between 16 and 16384 pixels.")
        } else if value % 2 != 0 {
            issues.append("\(name) must be an even number.")
        }
    }
}
