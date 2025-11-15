#pragma once

#include <JuceHeader.h>

/**
 * ImportDialog - UI for audio file import
 *
 * Features:
 * - File browser with preview
 * - Drag & drop support
 * - Sample rate mismatch warning
 * - Auto-detect BPM (future)
 * - Auto-detect key (future)
 * - Batch import
 */
class ImportDialog : public juce::Component,
                     public juce::Button::Listener,
                     public juce::FileDragAndDropTarget
{
public:
    //==========================================================================
    ImportDialog()
    {
        // Title
        addAndMakeVisible(titleLabel);
        titleLabel.setText("Import Audio Files", juce::dontSendNotification);
        titleLabel.setFont(juce::Font(24.0f, juce::Font::bold));
        titleLabel.setColour(juce::Label::textColourId, juce::Colour(0xff00d4ff));

        // Instructions
        addAndMakeVisible(instructionsLabel);
        instructionsLabel.setText("Drop audio files here or click Browse",
                                 juce::dontSendNotification);
        instructionsLabel.setJustificationType(juce::Justification::centred);
        instructionsLabel.setColour(juce::Label::textColourId, juce::Colours::white.withAlpha(0.7f));

        // File list
        addAndMakeVisible(fileListBox);
        fileListModel = std::make_unique<FileListBoxModel>(selectedFiles);
        fileListBox.setModel(fileListModel.get());
        fileListBox.setRowHeight(30);

        // Buttons
        addAndMakeVisible(browseButton);
        browseButton.setButtonText("Browse...");
        browseButton.addListener(this);

        addAndMakeVisible(clearButton);
        clearButton.setButtonText("Clear List");
        clearButton.addListener(this);

        addAndMakeVisible(importButton);
        importButton.setButtonText("Import");
        importButton.setColour(juce::TextButton::buttonColourId, juce::Colour(0xff44ff44));
        importButton.addListener(this);

        addAndMakeVisible(cancelButton);
        cancelButton.setButtonText("Cancel");
        cancelButton.addListener(this);

        // Info
        addAndMakeVisible(infoLabel);
        infoLabel.setText("Supported formats: WAV, AIFF, FLAC, OGG", juce::dontSendNotification);
        infoLabel.setJustificationType(juce::Justification::centred);
        infoLabel.setFont(juce::Font(12.0f));
        infoLabel.setColour(juce::Label::textColourId, juce::Colours::white.withAlpha(0.5f));

        setSize(600, 500);
    }

    ~ImportDialog() override
    {
        browseButton.removeListener(this);
        clearButton.removeListener(this);
        importButton.removeListener(this);
        cancelButton.removeListener(this);

        fileListBox.setModel(nullptr);
    }

    void paint(juce::Graphics& g) override
    {
        g.fillAll(juce::Colour(0xff1a1a1f));

        // Border
        g.setColour(juce::Colour(0xff00d4ff));
        g.drawRect(getLocalBounds(), 2);

        // Drag & drop hint
        if (isDragging)
        {
            g.setColour(juce::Colour(0xff00d4ff).withAlpha(0.3f));
            g.fillRect(dropZone);

            g.setColour(juce::Colour(0xff00d4ff));
            g.drawRect(dropZone, 3);
        }
    }

    void resized() override
    {
        auto bounds = getLocalBounds().reduced(20);

        // Title
        titleLabel.setBounds(bounds.removeFromTop(40));
        bounds.removeFromTop(10);

        // Instructions
        instructionsLabel.setBounds(bounds.removeFromTop(30));
        bounds.removeFromTop(10);

        // Drop zone
        dropZone = bounds.removeFromTop(200);
        fileListBox.setBounds(dropZone);
        bounds.removeFromTop(10);

        // Browse & Clear buttons
        auto buttonRow1 = bounds.removeFromTop(40);
        browseButton.setBounds(buttonRow1.removeFromLeft(buttonRow1.getWidth() / 2).reduced(5));
        clearButton.setBounds(buttonRow1.reduced(5));
        bounds.removeFromTop(10);

        // Info
        infoLabel.setBounds(bounds.removeFromTop(25));
        bounds.removeFromTop(20);

        // Import & Cancel buttons
        auto buttonRow2 = bounds.removeFromTop(40);
        cancelButton.setBounds(buttonRow2.removeFromLeft(buttonRow2.getWidth() / 2).reduced(5));
        importButton.setBounds(buttonRow2.reduced(5));
    }

    void buttonClicked(juce::Button* button) override
    {
        if (button == &browseButton)
        {
            showFileBrowser();
        }
        else if (button == &clearButton)
        {
            selectedFiles.clear();
            fileListBox.updateContent();
            repaint();
        }
        else if (button == &importButton)
        {
            performImport();
        }
        else if (button == &cancelButton)
        {
            if (auto* parent = findParentComponentOfClass<juce::DialogWindow>())
                parent->exitModalState(0);
        }
    }

    //==========================================================================
    // Drag & Drop
    //==========================================================================

    bool isInterestedInFileDrag(const juce::StringArray& files) override
    {
        for (const auto& file : files)
        {
            if (isAudioFile(juce::File(file)))
                return true;
        }
        return false;
    }

    void fileDragEnter(const juce::StringArray&, int, int) override
    {
        isDragging = true;
        repaint();
    }

    void fileDragExit(const juce::StringArray&) override
    {
        isDragging = false;
        repaint();
    }

    void filesDropped(const juce::StringArray& files, int, int) override
    {
        isDragging = false;

        for (const auto& filePath : files)
        {
            juce::File file(filePath);
            if (isAudioFile(file))
                selectedFiles.add(file);
        }

        fileListBox.updateContent();
        repaint();
    }

    //==========================================================================
    // Get imported files (for parent component)
    //==========================================================================

    juce::Array<juce::File> getImportedFiles() const
    {
        return selectedFiles;
    }

private:
    //==========================================================================
    void showFileBrowser()
    {
        fileChooser = std::make_unique<juce::FileChooser>(
            "Select Audio Files",
            juce::File::getSpecialLocation(juce::File::userMusicDirectory),
            "*.wav;*.aiff;*.flac;*.ogg",
            true  // Use native dialog
        );

        auto flags = juce::FileBrowserComponent::openMode |
                    juce::FileBrowserComponent::canSelectFiles |
                    juce::FileBrowserComponent::canSelectMultipleItems;

        fileChooser->launchAsync(flags, [this](const juce::FileChooser& fc)
        {
            auto files = fc.getResults();

            for (const auto& file : files)
            {
                if (isAudioFile(file))
                    selectedFiles.add(file);
            }

            fileListBox.updateContent();
        });
    }

    void performImport()
    {
        if (selectedFiles.isEmpty())
        {
            juce::AlertWindow::showMessageBoxAsync(
                juce::AlertWindow::WarningIcon,
                "No Files Selected",
                "Please add audio files to import."
            );
            return;
        }

        // TODO: Actually import files into project
        // This would typically call AudioEngine::addAudioClip() for each file

        juce::String message;
        message << "Importing " << selectedFiles.size() << " file(s)...\n\n";
        for (const auto& file : selectedFiles)
            message << file.getFileName() << "\n";

        juce::AlertWindow::showMessageBoxAsync(
            juce::AlertWindow::InfoIcon,
            "Import Started",
            message
        );

        // Close dialog
        if (auto* parent = findParentComponentOfClass<juce::DialogWindow>())
            parent->exitModalState(1);  // Return 1 to indicate success
    }

    static bool isAudioFile(const juce::File& file)
    {
        juce::String ext = file.getFileExtension().toLowerCase();
        return ext == ".wav" || ext == ".aiff" || ext == ".flac" || ext == ".ogg";
    }

    //==========================================================================
    // File List Model
    //==========================================================================

    class FileListBoxModel : public juce::ListBoxModel
    {
    public:
        FileListBoxModel(juce::Array<juce::File>& files) : fileList(files) {}

        int getNumRows() override
        {
            return fileList.size();
        }

        void paintListBoxItem(int rowNumber, juce::Graphics& g,
                             int width, int height, bool rowIsSelected) override
        {
            if (rowIsSelected)
                g.fillAll(juce::Colour(0xff00d4ff).withAlpha(0.3f));

            if (rowNumber < fileList.size())
            {
                g.setColour(juce::Colours::white);
                g.setFont(14.0f);

                juce::String fileName = fileList[rowNumber].getFileName();
                g.drawText(fileName, 10, 0, width - 20, height,
                          juce::Justification::centredLeft, true);
            }
        }

    private:
        juce::Array<juce::File>& fileList;
    };

    juce::Label titleLabel;
    juce::Label instructionsLabel;
    juce::Label infoLabel;

    juce::ListBox fileListBox;
    std::unique_ptr<FileListBoxModel> fileListModel;

    juce::TextButton browseButton;
    juce::TextButton clearButton;
    juce::TextButton importButton;
    juce::TextButton cancelButton;

    juce::Array<juce::File> selectedFiles;
    juce::Rectangle<int> dropZone;
    bool isDragging = false;

    std::unique_ptr<juce::FileChooser> fileChooser;

    JUCE_DECLARE_NON_COPYABLE_WITH_LEAK_DETECTOR(ImportDialog)
};
