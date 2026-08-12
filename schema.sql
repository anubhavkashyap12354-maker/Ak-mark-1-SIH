-- ====================================================================
-- SIH CIVIC GRIEVANCE REDRESSAL SYSTEM - SUPABASE POSTGRESQL SCHEMA
-- ====================================================================

-- Enable UUID extension if not enabled
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";
CREATE EXTENSION IF NOT EXISTS "pgcrypto";

-- --------------------------------------------------------------------
-- 1. USERS TABLE
-- --------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.users (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    phone_number VARCHAR(20) NOT NULL UNIQUE,
    preferred_language VARCHAR(10) NOT NULL DEFAULT 'en',
    created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP
);

COMMENT ON TABLE public.users IS 'Stores registered citizens and their communication preferences.';
COMMENT ON COLUMN public.users.phone_number IS 'Primary identifier for citizens accessing the system via SMS/WhatsApp/Voice.';

-- --------------------------------------------------------------------
-- 2. DEPARTMENTS TABLE
-- --------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.departments (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    name VARCHAR(100) NOT NULL UNIQUE,
    officer_email VARCHAR(255) NOT NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP
);

COMMENT ON TABLE public.departments IS 'Government departments responsible for resolving grievances.';

-- --------------------------------------------------------------------
-- 3. COMPLAINTS TABLE
-- --------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.complaints (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    tracking_id VARCHAR(50) NOT NULL UNIQUE,
    citizen_phone VARCHAR(20) NOT NULL REFERENCES public.users(phone_number) ON DELETE CASCADE ON UPDATE CASCADE,
    raw_text TEXT NOT NULL,
    translated_text TEXT,
    department_id UUID REFERENCES public.departments(id) ON DELETE SET NULL,
    urgency VARCHAR(20) NOT NULL DEFAULT 'MEDIUM' CHECK (urgency IN ('LOW', 'MEDIUM', 'HIGH', 'CRITICAL')),
    status VARCHAR(20) NOT NULL DEFAULT 'PENDING' CHECK (status IN ('PENDING', 'IN_PROGRESS', 'RESOLVED', 'REJECTED')),
    lat NUMERIC(10, 8),
    long NUMERIC(11, 8),
    photo_url TEXT,
    created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP
);

COMMENT ON TABLE public.complaints IS 'Main grievance repository including AI-processed translation and routing metadata.';

-- --------------------------------------------------------------------
-- 4. STATUS_LOGS TABLE
-- --------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.status_logs (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    complaint_id UUID NOT NULL REFERENCES public.complaints(id) ON DELETE CASCADE,
    old_status VARCHAR(20),
    new_status VARCHAR(20) NOT NULL,
    notes TEXT,
    updated_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP
);

COMMENT ON TABLE public.status_logs IS 'Audit trail tracking status transitions and officer notes for every complaint.';

-- --------------------------------------------------------------------
-- INDEXES FOR PERFORMANCE OPTIMIZATION
-- --------------------------------------------------------------------
CREATE INDEX IF NOT EXISTS idx_users_phone ON public.users(phone_number);
CREATE INDEX IF NOT EXISTS idx_complaints_tracking_id ON public.complaints(tracking_id);
CREATE INDEX IF NOT EXISTS idx_complaints_citizen_phone ON public.complaints(citizen_phone);
CREATE INDEX IF NOT EXISTS idx_complaints_department_id ON public.complaints(department_id);
CREATE INDEX IF NOT EXISTS idx_complaints_status ON public.complaints(status);
CREATE INDEX IF NOT EXISTS idx_complaints_urgency ON public.complaints(urgency);
CREATE INDEX IF NOT EXISTS idx_status_logs_complaint_id ON public.status_logs(complaint_id);

-- --------------------------------------------------------------------
-- AUTOMATED TRIGGERS & FUNCTIONS
-- --------------------------------------------------------------------

-- Function: Automatically update updated_at timestamp on complaints
CREATE OR REPLACE FUNCTION update_complaints_updated_at()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = CURRENT_TIMESTAMP;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE TRIGGER trg_update_complaints_timestamp
BEFORE UPDATE ON public.complaints
FOR EACH ROW
EXECUTE FUNCTION update_complaints_updated_at();

-- Function: Automatically log status changes into status_logs
CREATE OR REPLACE FUNCTION log_complaint_status_change()
RETURNS TRIGGER AS $$
BEGIN
    IF (TG_OP = 'INSERT') THEN
        INSERT INTO public.status_logs (complaint_id, old_status, new_status, notes)
        VALUES (NEW.id, NULL, NEW.status, 'Complaint created');
    ELSIF (TG_OP = 'UPDATE' AND OLD.status IS DISTINCT FROM NEW.status) THEN
        INSERT INTO public.status_logs (complaint_id, old_status, new_status, notes)
        VALUES (NEW.id, OLD.status, NEW.status, 'Status updated');
    END IF;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE TRIGGER trg_log_complaint_status
AFTER INSERT OR UPDATE ON public.complaints
FOR EACH ROW
EXECUTE FUNCTION log_complaint_status_change();

-- --------------------------------------------------------------------
-- INITIAL SEED DATA (DEFAULT DEPARTMENTS)
-- --------------------------------------------------------------------
INSERT INTO public.departments (name, officer_email) VALUES
('Roads & Infrastructure', 'roads.officer@civic.gov.in'),
('Water Supply & Sanitation', 'water.officer@civic.gov.in'),
('Electricity & Power Distribution', 'power.officer@civic.gov.in'),
('Waste Management & Hygiene', 'sanitation.officer@civic.gov.in'),
('Public Health & Safety', 'health.officer@civic.gov.in')
ON CONFLICT (name) DO NOTHING;
