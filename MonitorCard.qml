import QtQuick
import qs.Commons
import qs.Commons as Commons
import qs.Ui

// The card itself. Every visible string is handed in already translated so this
// file stays a pure presentation of one monitor.
BorderSurface {
  id: card

  property string numberText: "1"
  property string labelText: "Display"
  property string titleText: ""
  property string subtitleText: ""
  property string workspaceText: ""
  property string positionText: ""

  readonly property int pad: Math.round(Commons.Style.space(18))
  readonly property int gap: Math.round(Commons.Style.space(18))
  readonly property int numberBoxWidth: Math.round(Commons.Style.space(58))
  readonly property int numberBoxHeight: Math.round(Commons.Style.space(50))
  readonly property int textWidth: Math.round(Commons.Style.space(250))
  readonly property color muted: Commons.Util.alpha(Commons.Color.popups.text, 0.62)

  implicitWidth: card.borderLeft + card.pad + row.implicitWidth + card.pad + card.borderRight
  implicitHeight: card.borderTop + card.pad + row.implicitHeight + card.pad + card.borderBottom

  color: Commons.Util.alpha(Commons.Color.popups.background, 0.97)
  borderSpec: Border.surfaceSpec("popups", "border", Commons.Color.popups.border, Math.max(1, Commons.Style.space(2)))
  radius: Commons.Style.cornerRadius

  Row {
    id: row
    x: card.borderLeft + card.pad
    y: card.borderTop + card.pad
    spacing: card.gap

    Column {
      anchors.verticalCenter: parent.verticalCenter
      spacing: Math.round(Commons.Style.space(4))

      Rectangle {
        width: card.numberBoxWidth
        height: card.numberBoxHeight
        radius: Math.min(Math.round(Commons.Style.space(6)), Commons.Style.cornerRadius)
        color: Commons.Util.alpha(Commons.Color.accent, 0.14)
        border.width: Math.max(1, Math.round(Commons.Style.space(1)))
        border.color: Commons.Util.alpha(Commons.Color.accent, 0.75)

        Text {
          textFormat: Text.PlainText
          anchors.centerIn: parent
          text: card.numberText
          color: Commons.Color.accent
          font.family: Commons.Style.font.family
          font.pixelSize: Math.round(Commons.Style.font.displayLarge * 1.25)
          font.bold: true
        }
      }

      Text {
        textFormat: Text.PlainText
        anchors.horizontalCenter: parent.horizontalCenter
        text: card.labelText
        color: card.muted
        font.family: Commons.Style.font.family
        font.pixelSize: Commons.Style.font.caption
      }
    }

    Column {
      anchors.verticalCenter: parent.verticalCenter
      spacing: Math.round(Commons.Style.space(3))

      Row {
        spacing: Math.round(Commons.Style.space(8))

        Text {
          id: title
          textFormat: Text.PlainText
          width: Math.min(implicitWidth, card.textWidth)
          text: card.titleText
          color: Commons.Color.popups.text
          font.family: Commons.Style.font.family
          font.pixelSize: Commons.Style.font.heading
          font.bold: true
          elide: Text.ElideRight
          maximumLineCount: 1
        }

        Text {
          textFormat: Text.PlainText
          anchors.verticalCenter: title.verticalCenter
          text: card.positionText
          color: card.muted
          font.family: Commons.Style.font.family
          font.pixelSize: Commons.Style.font.bodySmall
        }
      }

      Text {
        textFormat: Text.PlainText
        visible: card.subtitleText !== ""
        width: Math.min(implicitWidth, card.textWidth)
        text: card.subtitleText
        color: card.muted
        font.family: Commons.Style.font.family
        font.pixelSize: Commons.Style.font.bodySmall
        elide: Text.ElideRight
        maximumLineCount: 1
      }

      Text {
        textFormat: Text.PlainText
        visible: card.workspaceText !== ""
        width: Math.min(implicitWidth, card.textWidth)
        text: card.workspaceText
        color: card.muted
        font.family: Commons.Style.font.family
        font.pixelSize: Commons.Style.font.bodySmall
        elide: Text.ElideRight
        maximumLineCount: 1
      }
    }
  }
}
