# Assessment Risk Tracking System

## Overview
This system enables comprehensive tracking of assessment responses, risk identification in answers, approval workflows, and automatic conversion of approved risks to the Risk module.

## Features

### 1. **Assessment Submission** (AssessmentForm.vue)
- Users receive assessment via email notification
- Access assessment at `/assessment/{id}` 
- Answer questions with different input types (text, radio, checkbox)
- **Save Draft** - Save progress without submitting
- **Submit** - Final submission of assessment
- Auto-saves and loads existing answers if user returns

### 2. **Assessment Results Tracking** (AssessmentResult Model)
Stores comprehensive data:
- `assessment_id` - Link to assessment
- `user_id` & `user_email` - Respondent details
- `answers` - Array of {question_id, answer}
- `completion_percentage` - Auto-calculated
- `status` - 'in_progress', 'submitted', 'under_review'
- `has_risks` - Boolean flag for risky answers
- `risk_items` - Array of flagged risks with descriptions & severity
- `approval_status` - 'pending', 'approved', 'rejected'
- `converted_to_risks` - Boolean if converted to Risk module
- `converted_risk_ids` - Array of created risk IDs

### 3. **Risk Flagging** (AssessmentsResults.vue)
Administrators can:
- Review all submitted assessments
- View individual answers
- **Flag specific answers as risks**
  - Select question(s) containing risks
  - Add risk description
  - Set severity (low, medium, high, critical)
- Multiple risks can be flagged per assessment

### 4. **Approval Workflow**
- Flagged assessments show "Pending" approval status
- Administrators can:
  - **Approve** - Green checkmark, enables risk conversion
  - **Reject** - Red X, marks as rejected
- Approval status tracked with timestamp and approver ID

### 5. **Risk Conversion to Risk Module**
- **Approved** risks can be converted to Risk records
- Conversion creates Risk entries with:
  - Subject: Risk description from flag
  - Description: Original answer text
  - Severity mapping to Impact/Likelihood levels
  - Links back to assessment source
  - Optional: category, owner, location, assets
- Tracks converted risk IDs for reference
- Prevents duplicate conversions

## API Endpoints

### Backend Routes (`/api/assessment-results/`)

#### Submit/Update Answers
```
POST /api/assessment-results/submit
Body: {
  assessment_id, 
  user_id, 
  user_email, 
  answers: [{question_id, answer}],
  submit: true/false
}
```

#### Flag Risks
```
POST /api/assessment-results/{id}/flag-risks
Body: {
  risk_items: [{
    question_id,
    risk_description,
    severity: 'low|medium|high|critical'
  }]
}
```

#### Approve Risks
```
POST /api/assessment-results/{id}/approve-risks
```

#### Reject Risks
```
POST /api/assessment-results/{id}/reject-risks
```

#### Convert to Risks
```
POST /api/assessment-results/{id}/convert-to-risks
Body: {
  category_id?,
  owner_id?,
  location_ids?,
  asset_ids?
}
```

#### Get Pending Approvals
```
GET /api/assessment-results/pending-approvals
```

#### Get User's Result
```
GET /api/assessment-results/user/{userId}/assessment/{assessmentId}
```

## Frontend Pages

### 1. **AssessmentForm.vue** (`/assessment/{id}`)
- User-facing assessment form
- Clean Google Forms-like interface
- Radio buttons, checkboxes, text inputs
- Save draft & submit buttons
- Auto-loads previous answers

### 2. **AssessmentsResults.vue** (`/assessments-results`)
- Administrator dashboard
- DataTable showing all results with:
  - Assessment name
  - User email
  - Completion percentage (progress bar)
  - Status badge
  - Risk flag indicator
  - Approval status
  - Action buttons
- View details modal
- Flag risks modal
- Approve/Reject/Convert buttons

## Database Schema

### AssessmentResult Collection (MongoDB)
```javascript
{
  assessment_id: ObjectId,
  user_id: String,
  user_email: String,
  answers: [{
    question_id: String,
    answer: Mixed (String, Array, Number)
  }],
  completion_percentage: Number,
  status: String, // 'in_progress', 'submitted', 'under_review'
  submitted_at: Date,
  has_risks: Boolean,
  risk_items: [{
    question_id: String,
    risk_description: String,
    severity: String // 'low', 'medium', 'high', 'critical'
  }],
  approval_status: String, // 'pending', 'approved', 'rejected', null
  approved_by: String,
  approved_at: Date,
  converted_to_risks: Boolean,
  converted_risk_ids: [String],
  created_at: Date,
  updated_at: Date,
  deleted_at: Date
}
```

## Workflow Diagram

```
1. Admin Creates Assessment
   ↓
2. Admin Sends to Users (email notification)
   ↓
3. User Fills Assessment Form
   ↓
4. User Submits (or saves draft)
   ↓
5. Admin Reviews Results
   ↓
6. Admin Flags Risky Answers (if any)
   ↓
7. Status: "Under Review" / "Pending Approval"
   ↓
8. Admin Approves or Rejects Risks
   ↓
   ├─ If Approved:
   │   ↓
   │  9. Admin Converts to Risk Module
   │   ↓
   │  10. Risk Records Created
   │   ↓
   │  11. Status: "Converted"
   │
   └─ If Rejected:
       ↓
      9. Status: "Rejected"
```

## Key Classes

### Backend
- **Model**: `App\Models\AssessmentResult\AssessmentResult`
- **Repository**: `App\Repositories\Eloquent\AssessmentResult\AssessmentResultRepository`
- **Service**: `App\Services\Eloquent\AssessmentResult\AssessmentResultService`
- **Controller**: `App\Http\Controllers\AssessmentResult\AssessmentResultController`

### Frontend
- **API**: `AssessmentsResults.ts`
- **Form Page**: `Assessment/AssessmentForm.vue`
- **Results Page**: `AssessmentsResults/AssessmentsResults.vue`

## Testing the System

### 1. Submit an Assessment
```bash
# Open browser console at http://82.29.175.67:8080/assessment/{id}
# Fill in some answers
# Click "Submit" button
# Check console logs for payload and response
```

### 2. View Results
```
Navigate to: /assessments-results
```

### 3. Flag Risks
```
1. Click "Flag" button on submitted assessment
2. Select question(s) containing risks
3. Add risk descriptions
4. Set severity levels
5. Submit flags
```

### 4. Approve & Convert
```
1. Click "Approve" button on flagged assessment
2. Click "Convert to Risks" button
3. Check Risk module for new entries
```

## Troubleshooting

### Submit Button Not Working
1. Open browser console (F12)
2. Check for console.log messages
3. Verify user_id and user_email are set in localStorage
4. Check network tab for API calls
5. Verify backend routes are registered

### Routes Not Found
```bash
cd /var/www/html/grc/back
php artisan route:list | grep assessment-results
```

### Database Issues
```bash
# Check MongoDB connection
# Verify assessments_results collection exists
```

## Future Enhancements
- Bulk risk flagging
- Risk severity auto-detection using AI/keywords
- Email notifications for approval/rejection
- Risk conversion with custom mapping UI
- Analytics dashboard for risk trends
- Export assessment results to PDF/Excel
- Risk heat map visualization

## Notes
- All timestamps are in UTC
- Soft deletes enabled on AssessmentResult model
- MongoDB is the database backend
- JWT authentication required for all API endpoints

