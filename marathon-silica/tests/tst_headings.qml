import QtQuick
import QtTest
import Sailfish.Silica 1.0
import Marathon.Silica 1.0

TestCase {
    id: testCase

    name: "NativeHeadings"
    when: windowShown
    visible: true
    width: 1024
    height: 1440

    Component {
        id: headingComponent

        PageHeader {
            title: "<b>A long account, conversation or collection title</b>"
            description: "<i>A secondary address that identifies the correct source</i>"
        }
    }

    Component {
        id: sectionComponent

        SectionHeader {
            text: "<b>Shared accounts and settings with a long translated heading</b>"
        }
    }

    function test_pageIdentityRemainsReadable_data() {
        return [
            {
                tag: "phone",
                width: 320
            },
            {
                tag: "square",
                width: 720
            },
            {
                tag: "window",
                width: 1024
            }
        ];
    }

    function test_pageIdentityRemainsReadable(data) {
        const heading = createTemporaryObject(headingComponent, testCase, {
            width: data.width
        });
        verify(heading);
        tryVerify(() => heading._descriptionLabel !== null);
        heading._titleItem.font.pixelSize = Theme.fontSizeHuge;
        heading._descriptionLabel.font.pixelSize = Theme.fontSizeLarge;
        waitForPolish(heading);
        compare(heading._titleItem.textFormat, Text.PlainText);
        compare(heading._descriptionLabel.textFormat, Text.PlainText);
        verify(!heading._titleItem.truncated);
        verify(!heading._descriptionLabel.truncated);
        verify(heading._titleItem.x >= 0);
        tryVerify(() => heading._descriptionLabel.y + heading._descriptionLabel.height <= heading.height);
        compare(heading.Accessible.name, heading.title);
        compare(heading.Accessible.description, heading.description);
        heading.description = "";
        tryVerify(() => !heading._descriptionLabel.visible);
    }

    function test_sectionGrowsWithText() {
        const section = createTemporaryObject(sectionComponent, testCase, {
            width: 320
        });
        verify(section);
        section.font.pixelSize = Theme.fontSizeLarge;
        waitForPolish(section);
        compare(section.textFormat, Text.PlainText);
        verify(section.lineCount > 1);
        verify(!section.truncated);
        verify(section.height >= section.contentHeight + section.topPadding);
        const narrowHeight = section.height;
        section.width = 1024;
        tryVerify(() => section.height < narrowHeight);
        compare(section.Accessible.name, section.text);
    }
}
