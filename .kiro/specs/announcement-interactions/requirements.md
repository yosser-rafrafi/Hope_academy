# Requirements Document

## Introduction

This feature adds social interaction capabilities to the Hope Academy announcement feed, allowing users to react to announcements with emoji reactions and to post threaded comments. The goal is to transform the one-way announcement board into a two-way forum-style channel where parents (student role) and teachers can engage with school news, ask questions, and share feedback in a warm, community-oriented way.

The feature integrates with the existing Flutter/Firestore app and extends the current `AnnouncementModel`, `AnnouncementService`, and `AnnouncementsFeedWidget`.

---

## Glossary

- **Announcement**: A post published by an admin, sub-admin, or teacher, as represented by `AnnouncementModel`.
- **Reaction**: A single emoji response (👍 ❤️ 😮 😢 😡) attached by a user to an Announcement. Each user may hold at most one Reaction per Announcement at any time.
- **Comment**: A free-text reply posted by a user on an Announcement, stored as a sub-collection in Firestore.
- **Reactor**: A user (teacher or student role) who submits a Reaction.
- **Commenter**: A user (teacher or student role) who submits a Comment.
- **Author**: The user (admin, sub-admin, or teacher) who originally published the Announcement.
- **Reaction_Summary**: An aggregated map stored on the Announcement document that records the count of each Reaction type (e.g., `{"👍": 3, "❤️": 1}`).
- **Interaction_Bar**: The UI row displayed at the bottom of each announcement card showing the Reaction_Summary and a comment count, along with controls to react and open comments.
- **Comment_Thread**: The expandable or modal view that displays all Comments on an Announcement in chronological order, with a compose field.
- **Feed**: The `AnnouncementsFeedWidget` that renders the list of Announcements.
- **Interaction_Service**: The new Dart service class responsible for all Firestore reads and writes related to Reactions and Comments.

---

## Requirements

### Requirement 1: Emoji Reactions on Announcements

**User Story:** As a parent or teacher, I want to react to an announcement with an emoji, so that I can quickly express how I feel about school news without writing a full comment.

#### Acceptance Criteria

1. WHEN a user views an Announcement in the Feed, THE Feed SHALL display the Interaction_Bar below the announcement body showing the current Reaction_Summary and comment count.
2. WHEN a user taps the react button in the Interaction_Bar, THE Feed SHALL present a reaction picker containing exactly the five emoji options: 👍 ❤️ 😮 😢 😡.
3. WHEN a user selects a Reaction from the picker, THE Interaction_Service SHALL write that Reaction to Firestore and update the Reaction_Summary on the Announcement document atomically.
4. WHEN a user who has already reacted to an Announcement selects a different Reaction, THE Interaction_Service SHALL replace the previous Reaction with the new one and update the Reaction_Summary to reflect the change.
5. WHEN a user who has already reacted to an Announcement selects their existing Reaction again, THE Interaction_Service SHALL remove that Reaction and decrement the corresponding count in the Reaction_Summary.
6. WHILE a Reaction write is in progress, THE Feed SHALL display the updated reaction count optimistically so that the UI responds immediately without waiting for the Firestore round-trip.
7. IF a Reaction write to Firestore fails, THEN THE Feed SHALL revert the optimistic update and display an error snackbar to the user.
8. THE Feed SHALL highlight the Reactor's currently active Reaction emoji in the Interaction_Bar so the user can see which reaction they have chosen.
9. WHEN any user adds or removes a Reaction, THE Feed SHALL update the Reaction_Summary in real time for all users currently viewing the Feed.

---

### Requirement 2: Comments on Announcements

**User Story:** As a parent or teacher, I want to post a comment on an announcement, so that I can ask questions or share feedback directly with the school community.

#### Acceptance Criteria

1. WHEN a user taps the comment count or comment icon in the Interaction_Bar, THE Feed SHALL open the Comment_Thread for that Announcement.
2. WHEN the Comment_Thread opens, THE Feed SHALL display all existing Comments in ascending chronological order (oldest first).
3. WHEN the Comment_Thread is open, THE Feed SHALL display a compose field and a submit button at the bottom of the thread.
4. WHEN a user submits a non-empty comment text, THE Interaction_Service SHALL write the Comment to the Firestore `announcements/{id}/comments` sub-collection with the fields: `authorUid`, `authorName`, `authorRole`, `text`, `createdAt`.
5. WHEN a user attempts to submit an empty or whitespace-only comment, THE Feed SHALL prevent submission and keep the compose field focused.
6. WHEN a new Comment is written to Firestore, THE Feed SHALL display it in the Comment_Thread in real time without requiring a page refresh.
7. WHEN a Comment is displayed in the Comment_Thread, THE Feed SHALL show the commenter's display name, role label, comment text, and a relative timestamp (e.g. "2m ago").
8. IF the Firestore write for a Comment fails, THEN THE Interaction_Service SHALL return an error and THE Feed SHALL display an error snackbar to the user.
9. THE Feed SHALL display the total comment count in the Interaction_Bar and update it in real time as comments are added.

---

### Requirement 3: Moderation — Deleting Comments

**User Story:** As an admin or sub-admin, I want to delete inappropriate comments, so that I can maintain a safe and respectful community space.

#### Acceptance Criteria

1. WHEN a user with the admin or sub-admin role views a Comment in the Comment_Thread, THE Feed SHALL display a delete icon next to that Comment.
2. WHEN a Commenter views their own Comment in the Comment_Thread, THE Feed SHALL display a delete icon next to that Comment.
3. WHEN an authorised user taps the delete icon on a Comment, THE Interaction_Service SHALL delete that Comment document from Firestore.
4. WHEN a Comment is deleted, THE Feed SHALL remove it from the Comment_Thread in real time and decrement the comment count in the Interaction_Bar.
5. IF the Firestore delete for a Comment fails, THEN THE Feed SHALL display an error snackbar to the user and keep the Comment visible.

---

### Requirement 4: Permission Model

**User Story:** As a system administrator, I want only authenticated users with appropriate roles to react and comment, so that anonymous or unauthorised access cannot pollute the announcement feed.

#### Acceptance Criteria

1. THE Interaction_Service SHALL allow users with the teacher role to both react and comment on any Announcement.
2. THE Interaction_Service SHALL allow users with the student role to both react and comment on any Announcement.
3. THE Interaction_Service SHALL allow users with the admin or sub-admin role to react and comment on any Announcement.
4. IF an unauthenticated request attempts to write a Reaction or Comment, THEN THE Interaction_Service SHALL reject the write and THE Feed SHALL display an authentication error to the user.
5. THE Interaction_Service SHALL use the authenticated user's `uid` as the Reaction document ID within the `announcements/{id}/reactions` sub-collection so that each user can hold at most one Reaction per Announcement.

---

### Requirement 5: Data Persistence and Real-Time Sync

**User Story:** As a user, I want reactions and comments to be saved persistently and visible to other users in real time, so that the feed feels live and collaborative.

#### Acceptance Criteria

1. THE Interaction_Service SHALL store each Reaction as a document at path `announcements/{announcementId}/reactions/{userId}` in Firestore.
2. THE Interaction_Service SHALL store each Comment as a document in the sub-collection `announcements/{announcementId}/comments` with an auto-generated document ID.
3. THE Interaction_Service SHALL maintain a `reactionCounts` map field on the Announcement document that reflects the current tally of each Reaction type.
4. WHEN the Feed initialises for an Announcement, THE Interaction_Service SHALL stream the `reactions` sub-collection so that the current user's active Reaction is always reflected in the UI.
5. WHEN the Feed initialises for an Announcement, THE Interaction_Service SHALL stream the `comments` sub-collection ordered by `createdAt` ascending.
6. IF Firestore is temporarily unavailable, THEN THE Interaction_Service SHALL serve cached data from the Firestore offline cache and display a connectivity warning banner in the Feed.

---

### Requirement 6: Visual Design — Forum/Social Style

**User Story:** As a user, I want the announcement cards to feel like social forum posts rather than a corporate notice board, so that the app feels welcoming and encourages engagement.

#### Acceptance Criteria

1. THE Feed SHALL render the Interaction_Bar below the announcement text on every card, with the reaction emoji summary on the left and the comment count icon on the right.
2. WHEN zero reactions exist on an Announcement, THE Feed SHALL display a muted "React" prompt in the Interaction_Bar instead of an empty emoji row.
3. WHEN one or more Reactions exist, THE Feed SHALL display only the emoji types that have at least one vote, each followed by its count, in descending count order.
4. THE Feed SHALL render the Comment_Thread in a bottom sheet or inline expanded section (not a full-screen navigation push) to preserve the scrolling feed context.
5. THE Feed SHALL apply a subtle animated transition when the reaction picker appears and disappears.
6. WHERE the device theme is dark mode, THE Feed SHALL adapt the Interaction_Bar and Comment_Thread colours to maintain readable contrast ratios in accordance with the existing app theme.
