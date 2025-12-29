/**
 * EchoelEducation.h
 *
 * Learning Management System for Music Production
 *
 * Complete education platform:
 * - Interactive tutorials
 * - Learning paths & tracks
 * - Video courses
 * - Skill assessments
 * - Certificates & badges
 * - Progress tracking
 * - Mentorship matching
 * - Community challenges
 * - Live workshops
 * - Practice exercises
 *
 * Part of Ralph Wiggum Quantum Sauce Mode - Phase 2
 * "I'm Idaho!" - Ralph Wiggum
 */

#pragma once

#include <string>
#include <vector>
#include <map>
#include <set>
#include <memory>
#include <functional>
#include <chrono>
#include <optional>
#include <atomic>
#include <mutex>

namespace Echoel {

// ============================================================================
// Education Types
// ============================================================================

enum class SkillLevel {
    Beginner,
    Elementary,
    Intermediate,
    Advanced,
    Expert,
    Master
};

enum class ContentType {
    Video,
    Interactive,
    Article,
    Quiz,
    Exercise,
    Project,
    LiveSession,
    Download
};

enum class SkillCategory {
    // Production
    Composition,
    Arrangement,
    SoundDesign,
    Sampling,
    Beatmaking,
    SongWriting,

    // Technical
    Mixing,
    Mastering,
    Recording,
    Editing,
    Automation,

    // Software
    DAWBasics,
    Plugins,
    Synthesis,
    MIDI,
    AudioEffects,

    // Theory
    MusicTheory,
    Harmony,
    Rhythm,
    EarTraining,

    // Genre-Specific
    Electronic,
    HipHop,
    Pop,
    Rock,
    Classical,
    Jazz,
    Ambient,

    // Business
    Marketing,
    Distribution,
    Copyright,
    Monetization,

    // Performance
    DJing,
    LivePerformance,
    Improvisation
};

// ============================================================================
// Lesson & Course Structures
// ============================================================================

struct LessonStep {
    std::string id;
    std::string title;
    std::string content;
    ContentType type = ContentType::Video;

    // Media
    std::string videoUrl;
    std::string audioUrl;
    std::vector<std::string> imageUrls;

    // Interactive elements
    struct InteractiveElement {
        std::string id;
        std::string type;  // "slider", "button", "knob", etc.
        std::string targetParameter;
        std::string instruction;
    };
    std::vector<InteractiveElement> interactiveElements;

    // Duration
    std::chrono::seconds estimatedDuration{0};

    // Requirements
    std::vector<std::string> prerequisiteSteps;

    bool isOptional = false;
    bool requiresCompletion = true;
};

struct Lesson {
    std::string id;
    std::string title;
    std::string description;
    std::string thumbnailUrl;

    std::vector<LessonStep> steps;

    SkillLevel level = SkillLevel::Beginner;
    std::vector<SkillCategory> skills;
    std::vector<std::string> tags;

    std::chrono::minutes estimatedDuration{0};

    std::string instructorId;
    std::string instructorName;

    // Downloads
    std::vector<std::string> projectFiles;
    std::vector<std::string> resourceFiles;

    // Prerequisites
    std::vector<std::string> prerequisiteLessons;
    std::vector<std::string> requiredPlugins;

    // Stats
    int completionCount = 0;
    float averageRating = 0.0f;
    int reviewCount = 0;

    bool isFree = false;
    bool isPremiumOnly = false;
};

struct Course {
    std::string id;
    std::string title;
    std::string shortDescription;
    std::string fullDescription;
    std::string thumbnailUrl;
    std::string promoVideoUrl;

    struct Module {
        std::string id;
        std::string title;
        std::string description;
        std::vector<std::string> lessonIds;
        int sortOrder = 0;
    };
    std::vector<Module> modules;

    SkillLevel startLevel = SkillLevel::Beginner;
    SkillLevel endLevel = SkillLevel::Intermediate;
    std::vector<SkillCategory> skills;
    std::vector<std::string> tags;

    std::string instructorId;
    std::string instructorName;
    std::string instructorBio;
    std::string instructorAvatarUrl;

    // Pricing
    float price = 0.0f;
    bool includedInSubscription = true;

    // Stats
    int enrollmentCount = 0;
    int completionCount = 0;
    float averageRating = 0.0f;
    int reviewCount = 0;
    std::chrono::hours totalDuration{0};

    // Certificate
    bool offersCertificate = true;
    std::string certificateTemplate;

    std::chrono::system_clock::time_point publishedAt;
    std::chrono::system_clock::time_point lastUpdated;

    bool isPublished = false;
    bool isFeatured = false;
};

// ============================================================================
// Learning Path
// ============================================================================

struct LearningPath {
    std::string id;
    std::string title;
    std::string description;
    std::string thumbnailUrl;

    struct PathNode {
        std::string id;

        enum class Type {
            Course,
            Lesson,
            Quiz,
            Project,
            Milestone
        } type = Type::Course;

        std::string contentId;  // Course or lesson ID
        std::string title;

        std::vector<std::string> prerequisites;
        bool isRequired = true;

        int xpReward = 0;
    };

    std::vector<PathNode> nodes;

    SkillLevel startLevel = SkillLevel::Beginner;
    SkillLevel endLevel = SkillLevel::Expert;
    std::vector<SkillCategory> skills;

    std::chrono::hours estimatedDuration{0};

    // Career paths
    std::vector<std::string> careerOutcomes;

    // Certificate
    std::string certificateTitle;
    bool offersCertificate = true;

    int enrollmentCount = 0;
    int completionCount = 0;
};

// ============================================================================
// Quizzes & Assessments
// ============================================================================

struct QuizQuestion {
    std::string id;
    std::string question;

    enum class Type {
        MultipleChoice,
        MultipleSelect,
        TrueFalse,
        FillBlank,
        Matching,
        Ordering,
        Audio,       // Listen and answer
        Practical    // Do something in app
    } type = Type::MultipleChoice;

    std::vector<std::string> options;
    std::vector<int> correctAnswers;
    std::string explanation;

    // For audio questions
    std::string audioUrl;

    int points = 10;
    std::chrono::seconds timeLimit{0};
};

struct Quiz {
    std::string id;
    std::string title;
    std::string description;

    std::vector<QuizQuestion> questions;

    int passingScore = 70;  // Percentage
    int maxAttempts = 3;
    bool shuffleQuestions = true;
    bool showCorrectAnswers = true;

    std::chrono::minutes timeLimit{0};

    std::vector<SkillCategory> assessedSkills;
    SkillLevel level = SkillLevel::Beginner;
};

struct QuizAttempt {
    std::string id;
    std::string quizId;
    std::string oderId;

    std::map<std::string, std::vector<int>> answers;

    int score = 0;
    int maxScore = 0;
    float percentage = 0.0f;
    bool passed = false;

    std::chrono::system_clock::time_point startedAt;
    std::chrono::system_clock::time_point completedAt;
    std::chrono::seconds duration{0};
};

// ============================================================================
// Practice Exercises
// ============================================================================

struct Exercise {
    std::string id;
    std::string title;
    std::string description;
    std::string instructions;

    enum class Type {
        EarTraining,        // Identify intervals, chords
        Transcription,      // Transcribe audio
        Mixing,             // Mix a provided track
        SoundDesign,        // Recreate a sound
        Composition,        // Write in a style
        Arrangement,        // Arrange a song
        Technical,          // Specific technique
        FreeForm            // Open-ended
    } type = Type::EarTraining;

    // Resources
    std::string projectFileUrl;
    std::string referenceAudioUrl;
    std::vector<std::string> assets;

    // Goals
    struct Goal {
        std::string id;
        std::string description;
        std::string metric;
        float target = 0.0f;
    };
    std::vector<Goal> goals;

    // Hints
    std::vector<std::string> hints;

    SkillLevel level = SkillLevel::Beginner;
    std::vector<SkillCategory> skills;

    int xpReward = 0;
    std::chrono::minutes estimatedTime{0};
};

// ============================================================================
// Progress & Achievements
// ============================================================================

struct UserProgress {
    std::string oderId;

    // Completed content
    std::set<std::string> completedLessons;
    std::set<std::string> completedCourses;
    std::set<std::string> completedPaths;
    std::set<std::string> passedQuizzes;
    std::set<std::string> completedExercises;

    // In-progress
    std::map<std::string, float> courseProgress;  // courseId -> percentage
    std::map<std::string, float> pathProgress;

    // Time tracking
    std::chrono::hours totalLearningTime{0};
    std::map<std::string, std::chrono::minutes> timePerSkill;

    // Skill levels
    std::map<SkillCategory, float> skillLevels;  // 0.0 - 1.0

    // Streaks
    int currentStreak = 0;
    int longestStreak = 0;
    std::chrono::system_clock::time_point lastActivity;

    // XP
    int totalXP = 0;
    int weeklyXP = 0;
};

struct Certificate {
    std::string id;
    std::string oderId;
    std::string userName;

    std::string courseId;
    std::string courseName;
    std::string pathId;
    std::string pathName;

    std::string instructorName;
    std::string organizationName;

    std::chrono::system_clock::time_point issuedAt;
    std::chrono::system_clock::time_point expiresAt;

    std::string certificateNumber;
    std::string verificationUrl;
    std::string pdfUrl;

    // Blockchain verification (optional)
    std::string blockchainTxId;

    bool isValid = true;
};

// ============================================================================
// Mentorship
// ============================================================================

struct Mentor {
    std::string id;
    std::string name;
    std::string bio;
    std::string avatarUrl;

    std::vector<SkillCategory> expertise;
    SkillLevel level = SkillLevel::Expert;

    float hourlyRate = 0.0f;
    std::string currency = "USD";

    // Availability
    std::map<int, std::vector<std::pair<int, int>>> availability;  // day -> [(start, end)]

    // Stats
    int studentCount = 0;
    int sessionCount = 0;
    float averageRating = 0.0f;
    int reviewCount = 0;

    bool isAvailable = true;
};

struct MentorSession {
    std::string id;
    std::string mentorId;
    std::string studentId;

    std::chrono::system_clock::time_point scheduledAt;
    std::chrono::minutes duration{60};

    enum class Type {
        OneOnOne,
        PortfolioReview,
        TrackFeedback,
        CareerAdvice,
        TechnicalHelp
    } type = Type::OneOnOne;

    std::string topic;
    std::string notes;

    // Video call
    std::string meetingUrl;
    std::string recordingUrl;

    enum class Status {
        Scheduled,
        InProgress,
        Completed,
        Cancelled,
        NoShow
    } status = Status::Scheduled;

    // Payment
    float price = 0.0f;
    bool isPaid = false;
};

// ============================================================================
// Live Workshops
// ============================================================================

struct Workshop {
    std::string id;
    std::string title;
    std::string description;
    std::string thumbnailUrl;

    std::string hostId;
    std::string hostName;

    std::chrono::system_clock::time_point scheduledAt;
    std::chrono::minutes duration{90};

    int maxParticipants = 50;
    int currentParticipants = 0;

    float price = 0.0f;
    bool isFree = false;

    // Live stream
    std::string streamUrl;
    std::string chatUrl;

    // Recording
    bool willBeRecorded = true;
    std::string recordingUrl;

    std::vector<SkillCategory> skills;
    SkillLevel level = SkillLevel::Intermediate;

    enum class Status {
        Upcoming,
        Live,
        Ended,
        Cancelled
    } status = Status::Upcoming;
};

// ============================================================================
// Education Manager
// ============================================================================

class EducationManager {
public:
    static EducationManager& getInstance() {
        static EducationManager instance;
        return instance;
    }

    // ========================================================================
    // Course Discovery
    // ========================================================================

    std::vector<Course> searchCourses(
        const std::string& query,
        std::optional<SkillCategory> category = std::nullopt,
        std::optional<SkillLevel> level = std::nullopt) const {

        std::lock_guard<std::mutex> lock(mutex_);

        std::vector<Course> results;

        for (const auto& [id, course] : courses_) {
            if (!course.isPublished) continue;

            if (level && course.startLevel != *level) continue;

            if (category) {
                bool hasCategory = false;
                for (const auto& skill : course.skills) {
                    if (skill == *category) {
                        hasCategory = true;
                        break;
                    }
                }
                if (!hasCategory) continue;
            }

            if (!query.empty()) {
                std::string lowerQuery = query;
                std::transform(lowerQuery.begin(), lowerQuery.end(),
                               lowerQuery.begin(), ::tolower);

                std::string lowerTitle = course.title;
                std::transform(lowerTitle.begin(), lowerTitle.end(),
                               lowerTitle.begin(), ::tolower);

                if (lowerTitle.find(lowerQuery) == std::string::npos) {
                    continue;
                }
            }

            results.push_back(course);
        }

        return results;
    }

    std::vector<Course> getFeaturedCourses() const {
        std::lock_guard<std::mutex> lock(mutex_);

        std::vector<Course> featured;
        for (const auto& [id, course] : courses_) {
            if (course.isPublished && course.isFeatured) {
                featured.push_back(course);
            }
        }

        return featured;
    }

    std::vector<LearningPath> getLearningPaths() const {
        std::lock_guard<std::mutex> lock(mutex_);

        std::vector<LearningPath> paths;
        for (const auto& [id, path] : learningPaths_) {
            paths.push_back(path);
        }

        return paths;
    }

    // ========================================================================
    // Enrollment & Progress
    // ========================================================================

    bool enrollInCourse(const std::string& courseId) {
        std::lock_guard<std::mutex> lock(mutex_);

        auto it = courses_.find(courseId);
        if (it == courses_.end()) return false;

        enrolledCourses_.insert(courseId);
        userProgress_.courseProgress[courseId] = 0.0f;

        it->second.enrollmentCount++;

        return true;
    }

    bool enrollInPath(const std::string& pathId) {
        std::lock_guard<std::mutex> lock(mutex_);

        auto it = learningPaths_.find(pathId);
        if (it == learningPaths_.end()) return false;

        enrolledPaths_.insert(pathId);
        userProgress_.pathProgress[pathId] = 0.0f;

        it->second.enrollmentCount++;

        return true;
    }

    void completeLesson(const std::string& lessonId) {
        std::lock_guard<std::mutex> lock(mutex_);

        userProgress_.completedLessons.insert(lessonId);

        // Award XP
        auto it = lessons_.find(lessonId);
        if (it != lessons_.end()) {
            userProgress_.totalXP += 50;  // Base XP per lesson
            updateSkillProgress(it->second.skills);
        }

        // Update course progress
        updateCourseProgress();

        // Update streak
        updateStreak();
    }

    void completeCourse(const std::string& courseId) {
        std::lock_guard<std::mutex> lock(mutex_);

        userProgress_.completedCourses.insert(courseId);

        auto it = courses_.find(courseId);
        if (it != courses_.end()) {
            it->second.completionCount++;

            // Issue certificate
            if (it->second.offersCertificate) {
                issueCertificate(courseId, "");
            }

            userProgress_.totalXP += 500;  // Course completion bonus
        }
    }

    float getCourseProgress(const std::string& courseId) const {
        std::lock_guard<std::mutex> lock(mutex_);

        auto it = userProgress_.courseProgress.find(courseId);
        if (it != userProgress_.courseProgress.end()) {
            return it->second;
        }
        return 0.0f;
    }

    UserProgress getUserProgress() const {
        std::lock_guard<std::mutex> lock(mutex_);
        return userProgress_;
    }

    // ========================================================================
    // Quizzes
    // ========================================================================

    QuizAttempt startQuiz(const std::string& quizId) {
        std::lock_guard<std::mutex> lock(mutex_);

        QuizAttempt attempt;
        attempt.id = generateId("attempt");
        attempt.quizId = quizId;
        attempt.oderId = currentUserId_;
        attempt.startedAt = std::chrono::system_clock::now();

        currentQuizAttempt_ = attempt;

        return attempt;
    }

    void submitAnswer(const std::string& questionId, const std::vector<int>& answers) {
        std::lock_guard<std::mutex> lock(mutex_);

        currentQuizAttempt_.answers[questionId] = answers;
    }

    QuizAttempt finishQuiz() {
        std::lock_guard<std::mutex> lock(mutex_);

        currentQuizAttempt_.completedAt = std::chrono::system_clock::now();
        currentQuizAttempt_.duration = std::chrono::duration_cast<std::chrono::seconds>(
            currentQuizAttempt_.completedAt - currentQuizAttempt_.startedAt);

        // Calculate score
        auto quizIt = quizzes_.find(currentQuizAttempt_.quizId);
        if (quizIt != quizzes_.end()) {
            const auto& quiz = quizIt->second;
            int totalPoints = 0;
            int earnedPoints = 0;

            for (const auto& question : quiz.questions) {
                totalPoints += question.points;

                auto answerIt = currentQuizAttempt_.answers.find(question.id);
                if (answerIt != currentQuizAttempt_.answers.end()) {
                    if (answerIt->second == question.correctAnswers) {
                        earnedPoints += question.points;
                    }
                }
            }

            currentQuizAttempt_.maxScore = totalPoints;
            currentQuizAttempt_.score = earnedPoints;
            currentQuizAttempt_.percentage = totalPoints > 0 ?
                (static_cast<float>(earnedPoints) / totalPoints) * 100.0f : 0.0f;
            currentQuizAttempt_.passed = currentQuizAttempt_.percentage >= quiz.passingScore;

            if (currentQuizAttempt_.passed) {
                userProgress_.passedQuizzes.insert(currentQuizAttempt_.quizId);
                userProgress_.totalXP += 100;
            }
        }

        quizAttempts_[currentQuizAttempt_.id] = currentQuizAttempt_;

        return currentQuizAttempt_;
    }

    // ========================================================================
    // Exercises
    // ========================================================================

    void startExercise(const std::string& exerciseId) {
        std::lock_guard<std::mutex> lock(mutex_);
        currentExerciseId_ = exerciseId;
        exerciseStartTime_ = std::chrono::system_clock::now();
    }

    void completeExercise(const std::string& exerciseId, float score) {
        std::lock_guard<std::mutex> lock(mutex_);

        userProgress_.completedExercises.insert(exerciseId);

        auto it = exercises_.find(exerciseId);
        if (it != exercises_.end()) {
            int xp = static_cast<int>(it->second.xpReward * score);
            userProgress_.totalXP += xp;
            updateSkillProgress(it->second.skills);
        }
    }

    std::vector<Exercise> getExercises(
        std::optional<SkillCategory> category = std::nullopt,
        std::optional<SkillLevel> level = std::nullopt) const {

        std::lock_guard<std::mutex> lock(mutex_);

        std::vector<Exercise> results;
        for (const auto& [id, exercise] : exercises_) {
            if (level && exercise.level != *level) continue;

            if (category) {
                bool hasCategory = false;
                for (const auto& skill : exercise.skills) {
                    if (skill == *category) {
                        hasCategory = true;
                        break;
                    }
                }
                if (!hasCategory) continue;
            }

            results.push_back(exercise);
        }

        return results;
    }

    // ========================================================================
    // Certificates
    // ========================================================================

    std::string issueCertificate(const std::string& courseId, const std::string& pathId) {
        std::lock_guard<std::mutex> lock(mutex_);

        Certificate cert;
        cert.id = generateId("cert");
        cert.oderId = currentUserId_;
        cert.userName = currentUserName_;

        if (!courseId.empty()) {
            auto it = courses_.find(courseId);
            if (it != courses_.end()) {
                cert.courseId = courseId;
                cert.courseName = it->second.title;
                cert.instructorName = it->second.instructorName;
            }
        }

        if (!pathId.empty()) {
            auto it = learningPaths_.find(pathId);
            if (it != learningPaths_.end()) {
                cert.pathId = pathId;
                cert.pathName = it->second.title;
            }
        }

        cert.organizationName = "Echoel Academy";
        cert.issuedAt = std::chrono::system_clock::now();
        cert.certificateNumber = "ECHOEL-CERT-" + std::to_string(nextCertId_++);
        cert.verificationUrl = "https://echoel.com/verify/" + cert.certificateNumber;

        certificates_[cert.id] = cert;

        return cert.id;
    }

    std::vector<Certificate> getUserCertificates() const {
        std::lock_guard<std::mutex> lock(mutex_);

        std::vector<Certificate> result;
        for (const auto& [id, cert] : certificates_) {
            if (cert.oderId == currentUserId_) {
                result.push_back(cert);
            }
        }

        return result;
    }

    // ========================================================================
    // Mentorship
    // ========================================================================

    std::vector<Mentor> findMentors(
        std::optional<SkillCategory> expertise = std::nullopt) const {

        std::lock_guard<std::mutex> lock(mutex_);

        std::vector<Mentor> results;
        for (const auto& [id, mentor] : mentors_) {
            if (!mentor.isAvailable) continue;

            if (expertise) {
                bool hasExpertise = false;
                for (const auto& skill : mentor.expertise) {
                    if (skill == *expertise) {
                        hasExpertise = true;
                        break;
                    }
                }
                if (!hasExpertise) continue;
            }

            results.push_back(mentor);
        }

        return results;
    }

    std::string bookMentorSession(const std::string& mentorId,
                                   std::chrono::system_clock::time_point time,
                                   MentorSession::Type type) {
        std::lock_guard<std::mutex> lock(mutex_);

        MentorSession session;
        session.id = generateId("session");
        session.mentorId = mentorId;
        session.studentId = currentUserId_;
        session.scheduledAt = time;
        session.type = type;
        session.status = MentorSession::Status::Scheduled;

        auto mentorIt = mentors_.find(mentorId);
        if (mentorIt != mentors_.end()) {
            session.price = mentorIt->second.hourlyRate;
        }

        mentorSessions_[session.id] = session;

        return session.id;
    }

    // ========================================================================
    // Workshops
    // ========================================================================

    std::vector<Workshop> getUpcomingWorkshops() const {
        std::lock_guard<std::mutex> lock(mutex_);

        std::vector<Workshop> upcoming;
        auto now = std::chrono::system_clock::now();

        for (const auto& [id, workshop] : workshops_) {
            if (workshop.scheduledAt > now &&
                workshop.status == Workshop::Status::Upcoming) {
                upcoming.push_back(workshop);
            }
        }

        std::sort(upcoming.begin(), upcoming.end(),
            [](const Workshop& a, const Workshop& b) {
                return a.scheduledAt < b.scheduledAt;
            });

        return upcoming;
    }

    bool registerForWorkshop(const std::string& workshopId) {
        std::lock_guard<std::mutex> lock(mutex_);

        auto it = workshops_.find(workshopId);
        if (it == workshops_.end()) return false;

        if (it->second.currentParticipants >= it->second.maxParticipants) {
            return false;  // Full
        }

        it->second.currentParticipants++;
        registeredWorkshops_.insert(workshopId);

        return true;
    }

    // ========================================================================
    // Skill Recommendations
    // ========================================================================

    std::vector<std::string> getRecommendedNext() const {
        std::lock_guard<std::mutex> lock(mutex_);

        std::vector<std::string> recommendations;

        // Find uncompleted lessons in enrolled courses
        for (const auto& courseId : enrolledCourses_) {
            auto courseIt = courses_.find(courseId);
            if (courseIt == courses_.end()) continue;

            for (const auto& module : courseIt->second.modules) {
                for (const auto& lessonId : module.lessonIds) {
                    if (userProgress_.completedLessons.count(lessonId) == 0) {
                        recommendations.push_back(lessonId);
                        if (recommendations.size() >= 5) {
                            return recommendations;
                        }
                    }
                }
            }
        }

        return recommendations;
    }

    SkillLevel getSkillLevel(SkillCategory category) const {
        std::lock_guard<std::mutex> lock(mutex_);

        auto it = userProgress_.skillLevels.find(category);
        if (it != userProgress_.skillLevels.end()) {
            float level = it->second;
            if (level < 0.2f) return SkillLevel::Beginner;
            if (level < 0.4f) return SkillLevel::Elementary;
            if (level < 0.6f) return SkillLevel::Intermediate;
            if (level < 0.8f) return SkillLevel::Advanced;
            if (level < 0.95f) return SkillLevel::Expert;
            return SkillLevel::Master;
        }

        return SkillLevel::Beginner;
    }

private:
    EducationManager() = default;
    ~EducationManager() = default;

    EducationManager(const EducationManager&) = delete;
    EducationManager& operator=(const EducationManager&) = delete;

    std::string generateId(const std::string& prefix) {
        return prefix + "_" + std::to_string(nextId_++);
    }

    void updateCourseProgress() {
        for (const auto& courseId : enrolledCourses_) {
            auto courseIt = courses_.find(courseId);
            if (courseIt == courses_.end()) continue;

            int totalLessons = 0;
            int completedLessons = 0;

            for (const auto& module : courseIt->second.modules) {
                for (const auto& lessonId : module.lessonIds) {
                    totalLessons++;
                    if (userProgress_.completedLessons.count(lessonId) > 0) {
                        completedLessons++;
                    }
                }
            }

            if (totalLessons > 0) {
                userProgress_.courseProgress[courseId] =
                    static_cast<float>(completedLessons) / totalLessons;

                if (completedLessons == totalLessons) {
                    completeCourse(courseId);
                }
            }
        }
    }

    void updateSkillProgress(const std::vector<SkillCategory>& skills) {
        for (const auto& skill : skills) {
            userProgress_.skillLevels[skill] += 0.01f;  // Small increment
            if (userProgress_.skillLevels[skill] > 1.0f) {
                userProgress_.skillLevels[skill] = 1.0f;
            }
        }
    }

    void updateStreak() {
        auto now = std::chrono::system_clock::now();
        auto lastTime = std::chrono::system_clock::to_time_t(userProgress_.lastActivity);
        auto nowTime = std::chrono::system_clock::to_time_t(now);

        auto* lastTm = std::localtime(&lastTime);
        int lastDay = lastTm->tm_yday;

        auto* nowTm = std::localtime(&nowTime);
        int nowDay = nowTm->tm_yday;

        if (nowDay == lastDay + 1) {
            userProgress_.currentStreak++;
        } else if (nowDay != lastDay) {
            userProgress_.currentStreak = 1;
        }

        if (userProgress_.currentStreak > userProgress_.longestStreak) {
            userProgress_.longestStreak = userProgress_.currentStreak;
        }

        userProgress_.lastActivity = now;
    }

    mutable std::mutex mutex_;

    std::map<std::string, Course> courses_;
    std::map<std::string, Lesson> lessons_;
    std::map<std::string, LearningPath> learningPaths_;
    std::map<std::string, Quiz> quizzes_;
    std::map<std::string, QuizAttempt> quizAttempts_;
    std::map<std::string, Exercise> exercises_;
    std::map<std::string, Certificate> certificates_;
    std::map<std::string, Mentor> mentors_;
    std::map<std::string, MentorSession> mentorSessions_;
    std::map<std::string, Workshop> workshops_;

    std::set<std::string> enrolledCourses_;
    std::set<std::string> enrolledPaths_;
    std::set<std::string> registeredWorkshops_;

    UserProgress userProgress_;
    QuizAttempt currentQuizAttempt_;
    std::string currentExerciseId_;
    std::chrono::system_clock::time_point exerciseStartTime_;

    std::string currentUserId_ = "user_1";
    std::string currentUserName_ = "Student";

    std::atomic<int> nextId_{1};
    std::atomic<int> nextCertId_{1000};
};

// ============================================================================
// Convenience Functions
// ============================================================================

namespace Education {

inline std::vector<Course> searchCourses(const std::string& query) {
    return EducationManager::getInstance().searchCourses(query);
}

inline bool enroll(const std::string& courseId) {
    return EducationManager::getInstance().enrollInCourse(courseId);
}

inline void complete(const std::string& lessonId) {
    EducationManager::getInstance().completeLesson(lessonId);
}

inline UserProgress progress() {
    return EducationManager::getInstance().getUserProgress();
}

inline SkillLevel skillLevel(SkillCategory category) {
    return EducationManager::getInstance().getSkillLevel(category);
}

} // namespace Education

} // namespace Echoel
